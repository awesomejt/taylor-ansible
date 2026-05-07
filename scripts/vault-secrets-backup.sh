#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   vault-secrets-backup.sh [repo_dir] [backup_root] [keep_days]
# Example:
#   vault-secrets-backup.sh "$HOME/ansible" "$HOME/.ansible-vault-backups" 45

REPO_DIR="${1:-$HOME/ansible}"
BACKUP_ROOT="${2:-$HOME/.ansible-vault-backups}"
KEEP_DAYS="${3:-45}"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "ERROR: repo directory not found: $REPO_DIR" >&2
  exit 1
fi

if [[ ! -d "$REPO_DIR/vars" ]]; then
  echo "ERROR: vars directory not found under: $REPO_DIR" >&2
  exit 1
fi

mapfile -t SECRET_FILES < <(find "$REPO_DIR/vars" -type f -name 'secrets.yaml' | sort)

if [[ ${#SECRET_FILES[@]} -eq 0 ]]; then
  echo "ERROR: no secrets.yaml files found under $REPO_DIR/vars" >&2
  exit 1
fi

mkdir -p "$BACKUP_ROOT"
chmod 700 "$BACKUP_ROOT"

TS="$(date -u +%Y%m%d-%H%M%S)"
STAGE_DIR="$BACKUP_ROOT/.stage-$TS"
SNAPSHOT_TAR="$BACKUP_ROOT/$TS.tar.gz"

mkdir -p "$STAGE_DIR/files"

for src in "${SECRET_FILES[@]}"; do
  rel="${src#$REPO_DIR/}"
  dst="$STAGE_DIR/files/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
done

(
  cd "$STAGE_DIR/files"
  find . -type f | sort > "$STAGE_DIR/files.list"
)

(
  cd "$STAGE_DIR/files"
  : > "$STAGE_DIR/sha256sums.txt"
  while IFS= read -r rel_path; do
    sha256sum "$rel_path" >> "$STAGE_DIR/sha256sums.txt"
  done < "$STAGE_DIR/files.list"
)

tar -C "$STAGE_DIR" -czf "$SNAPSHOT_TAR" files files.list sha256sums.txt
chmod 600 "$SNAPSHOT_TAR"
rm -rf "$STAGE_DIR"

find "$BACKUP_ROOT" -maxdepth 1 -type f -name '*.tar.gz' -mtime "+$KEEP_DAYS" -delete

echo "Backup created: $SNAPSHOT_TAR"
echo "Files captured: ${#SECRET_FILES[@]}"
echo "Retention days: $KEEP_DAYS"
