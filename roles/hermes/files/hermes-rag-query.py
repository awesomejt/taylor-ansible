#!/usr/bin/env python3
"""Query shared web-memory vectors from Qdrant for Hermes workflows.

This utility is dependency-light (stdlib only) so it can run on Hermes hosts
without extra Python packages.
"""

import argparse
import hashlib
import json
import math
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def env_int(name: str, default: int) -> int:
    value = env(name, str(default)).strip()
    try:
        return int(value)
    except ValueError:
        return default


def normalize_vector(vector):
    norm = math.sqrt(sum(v * v for v in vector))
    if norm == 0:
        return vector
    return [v / norm for v in vector]


def hash_embed(text: str, dimension: int):
    vector = [0.0] * max(1, dimension)
    tokens = re.findall(r"[A-Za-z0-9_]{2,}", text.lower())
    if not tokens:
        return vector

    for token in tokens:
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        idx = int.from_bytes(digest[:4], "big") % len(vector)
        sign = 1.0 if digest[4] % 2 == 0 else -1.0
        vector[idx] += sign

    return normalize_vector(vector)


def json_post(url: str, payload: dict, timeout: int):
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        data = response.read().decode("utf-8")
        return json.loads(data)


def build_query_vector(text: str):
    provider = env("HERMES_RAG_EMBED_PROVIDER", "local-hash").strip().lower()
    dimension = env_int("HERMES_RAG_EMBED_DIMENSION", 384)
    ollama_url = env("HERMES_RAG_OLLAMA_URL", "http://192.168.50.51:11434").rstrip("/")
    ollama_model = env("HERMES_RAG_OLLAMA_MODEL", "nomic-embed-text:latest")
    ollama_timeout = env_int("HERMES_RAG_OLLAMA_TIMEOUT", 45)

    if provider == "ollama":
        try:
            payload = json_post(
                f"{ollama_url}/api/embed",
                {"model": ollama_model, "input": [text]},
                ollama_timeout,
            )
            embeddings = payload.get("embeddings") or []
            if isinstance(embeddings, list) and len(embeddings) == 1:
                return embeddings[0]
        except Exception as exc:  # noqa: BLE001
            print(f"WARN ollama /api/embed failed: {exc}", file=sys.stderr)

        try:
            payload = json_post(
                f"{ollama_url}/api/embeddings",
                {"model": ollama_model, "prompt": text},
                ollama_timeout,
            )
            embedding = payload.get("embedding")
            if embedding:
                return embedding
        except Exception as exc:  # noqa: BLE001
            print(f"WARN ollama /api/embeddings failed: {exc}", file=sys.stderr)

    return hash_embed(text, dimension)


def query_qdrant(url: str, collection: str, vector, limit: int):
    base = url.rstrip("/")
    encoded_collection = urllib.parse.quote(collection, safe="")
    endpoint = f"{base}/collections/{encoded_collection}/points/search"
    payload = {
        "vector": vector,
        "limit": max(1, limit),
        "with_payload": True,
    }
    data = json_post(endpoint, payload, 30)
    return data.get("result") or []


def main() -> int:
    parser = argparse.ArgumentParser(description="Query Hermes web-memory vectors")
    parser.add_argument("query", type=str, help="Query text")
    parser.add_argument("--top-k", type=int, default=8, help="Number of results")
    args = parser.parse_args()

    qdrant_url = env("HERMES_RAG_QDRANT_URL") or env("QDRANT_URL")
    qdrant_collection = env("HERMES_RAG_QDRANT_COLLECTION")

    if not qdrant_url:
        print("Missing HERMES_RAG_QDRANT_URL or QDRANT_URL", file=sys.stderr)
        return 1
    if not qdrant_collection:
        print("Missing HERMES_RAG_QDRANT_COLLECTION", file=sys.stderr)
        return 1

    query_text = args.query.strip()
    if not query_text:
        print("Query must not be empty", file=sys.stderr)
        return 1

    try:
        vector = build_query_vector(query_text)
        hits = query_qdrant(qdrant_url, qdrant_collection, vector, args.top_k)
    except urllib.error.HTTPError as exc:
        print(f"Qdrant query failed: HTTP {exc.code}", file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"Qdrant query failed: {exc.reason}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"Qdrant query failed: {exc}", file=sys.stderr)
        return 1

    output = []
    for hit in hits:
        payload = hit.get("payload") or {}
        output.append(
            {
                "score": hit.get("score"),
                "url": payload.get("url"),
                "title": payload.get("title"),
                "domain": payload.get("domain"),
                "chunk_index": payload.get("chunk_index"),
                "text": payload.get("text"),
            }
        )

    print(json.dumps(output, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
