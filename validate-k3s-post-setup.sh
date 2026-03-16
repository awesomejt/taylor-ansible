#!/usr/bin/env bash
set -euo pipefail

TARGET_ENV="prod"
ALLOW_PROGRESSING="false"

for argument in "$@"; do
  case "$argument" in
    stage|prod)
      TARGET_ENV="$argument"
      ;;
    --allow-progressing)
      ALLOW_PROGRESSING="true"
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: ./validate-k3s-post-setup.sh [stage|prod] [--allow-progressing]

Defaults:
  env: prod

Options:
  --allow-progressing   Do not fail when Argo app health is Progressing
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $argument" >&2
      exit 2
      ;;
  esac
done

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not installed." >&2
  exit 2
fi

failures=0
warnings=0

pass() {
  printf '[PASS] %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf '[FAIL] %s\n' "$1"
}

check_namespace_exists() {
  local namespace_name="$1"
  if kubectl get namespace "$namespace_name" >/dev/null 2>&1; then
    pass "Namespace exists: $namespace_name"
  else
    fail "Namespace missing: $namespace_name"
  fi
}

check_nodes_ready() {
  # Ensure every node reports Ready==True
  local total
  local ready

  total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  ready=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name} {.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | awk '$2=="True"{c++} END{print c+0}')

  if [[ -z "$total" || "$total" -eq 0 ]]; then
    fail "No nodes found in cluster"
    return
  fi

  if [[ "$ready" -lt "$total" ]]; then
    fail "Not all nodes Ready: ${ready}/${total}"
  else
    pass "All nodes Ready: ${ready}/${total}"
  fi
}

check_kube_system_pods() {
  # Ensure kube-system pods are generally healthy (not Pending/CrashLoopBackOff)
  local bad
  bad=$(kubectl -n kube-system get pods --no-headers 2>/dev/null | awk '$3 != "Running" && $3 != "Completed" {print $0}')
  if [[ -n "$bad" ]]; then
    fail "Some kube-system pods are not healthy:\n$bad"
  else
    pass "kube-system pods are healthy"
  fi
}

echo "Validating Kubernetes connectivity..."
current_context="$(kubectl config current-context 2>/dev/null || true)"
if [[ -z "$current_context" ]]; then
  fail "kubectl context is not configured"
else
  pass "kubectl context: $current_context"
  if [[ "$current_context" != *"$TARGET_ENV"* ]]; then
    warn "Context '$current_context' does not include env '$TARGET_ENV'"
  fi
fi

if kubectl cluster-info >/dev/null 2>&1; then
  pass "Kubernetes API reachable"
else
  fail "Kubernetes API not reachable"
fi

echo
echo "Running focused infrastructure checks..."
check_nodes_ready
check_kube_system_pods

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Infrastructure validation completed successfully for env=$TARGET_ENV"
  if [[ "$warnings" -gt 0 ]]; then
    echo "Warnings: $warnings"
  fi
  exit 0
fi

echo "Infrastructure validation failed for env=$TARGET_ENV"
echo "Failures: $failures"
if [[ "$warnings" -gt 0 ]]; then
  echo "Warnings: $warnings"
fi
exit 1
