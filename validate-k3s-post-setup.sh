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

check_secret_exists() {
  local namespace_name="$1"
  local secret_name="$2"
  if kubectl -n "$namespace_name" get secret "$secret_name" >/dev/null 2>&1; then
    pass "Secret exists: $namespace_name/$secret_name"
  else
    fail "Secret missing: $namespace_name/$secret_name"
  fi
}

check_ingress_host_exists() {
  local expected_host="$1"
  if kubectl get ingress -A -o jsonpath='{range .items[*]}{range .spec.rules[*]}{.host}{"\n"}{end}{end}' | grep -Fxq "$expected_host"; then
    pass "Ingress host present: $expected_host"
  else
    fail "Ingress host missing: $expected_host"
  fi
}

check_certificate_ready() {
  local namespace_name="$1"
  local certificate_name="$2"
  if ! kubectl -n "$namespace_name" get certificate "$certificate_name" >/dev/null 2>&1; then
    fail "Certificate missing: $namespace_name/$certificate_name"
    return
  fi

  local ready_status
  ready_status="$(kubectl -n "$namespace_name" get certificate "$certificate_name" -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}')"
  if [[ "$ready_status" == "True" ]]; then
    pass "Certificate ready: $namespace_name/$certificate_name"
  else
    fail "Certificate not ready: $namespace_name/$certificate_name"
  fi
}

check_app_status() {
  local application_name="$1"
  local sync_status
  local health_status

  if ! kubectl -n argocd get application.argoproj.io "$application_name" >/dev/null 2>&1; then
    fail "Argo app missing: $application_name"
    return
  fi

  sync_status="$(kubectl -n argocd get application.argoproj.io "$application_name" -o jsonpath='{.status.sync.status}')"
  health_status="$(kubectl -n argocd get application.argoproj.io "$application_name" -o jsonpath='{.status.health.status}')"

  if [[ "$sync_status" != "Synced" ]]; then
    fail "Argo app not synced: $application_name (sync=$sync_status health=$health_status)"
    return
  fi

  if [[ "$health_status" == "Healthy" ]]; then
    pass "Argo app healthy: $application_name"
  elif [[ "$health_status" == "Progressing" && "$ALLOW_PROGRESSING" == "true" ]]; then
    warn "Argo app progressing (allowed): $application_name"
  else
    fail "Argo app not healthy: $application_name (sync=$sync_status health=$health_status)"
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
echo "Validating Argo CD applications..."
check_namespace_exists "argocd"

argocd_apps=(
  "homelab-${TARGET_ENV}"
  "cert-manager-issuers-${TARGET_ENV}"
  "metallb-${TARGET_ENV}"
  "metallb-config-${TARGET_ENV}"
  "external-dns-${TARGET_ENV}"
  "harbor-${TARGET_ENV}"
  "headlamp-${TARGET_ENV}"
  "reposilite-${TARGET_ENV}"
  "kube-prometheus-stack-${TARGET_ENV}"
)

for app_name in "${argocd_apps[@]}"; do
  check_app_status "$app_name"
done

echo
echo "Validating cert-manager issuer..."
if kubectl get clusterissuer letsencrypt-lab >/dev/null 2>&1; then
  issuer_ready_status="$(kubectl get clusterissuer letsencrypt-lab -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}')"
  if [[ "$issuer_ready_status" == "True" ]]; then
    pass "ClusterIssuer ready: letsencrypt-lab"
  else
    fail "ClusterIssuer not ready: letsencrypt-lab"
  fi
else
  fail "ClusterIssuer missing: letsencrypt-lab"
fi

echo
echo "Validating seeded secrets..."
check_namespace_exists "external-dns"
check_namespace_exists "monitoring"
check_namespace_exists "reposilite"
check_secret_exists "external-dns" "external-dns-rfc2136"
check_secret_exists "monitoring" "grafana-admin"
check_secret_exists "reposilite" "reposilite-admin"

echo
echo "Validating ingress hostnames..."
check_ingress_host_exists "harbor.${TARGET_ENV}.lab"
check_ingress_host_exists "headlamp.${TARGET_ENV}.lab"
check_ingress_host_exists "artifacts.${TARGET_ENV}.lab"
check_ingress_host_exists "grafana.${TARGET_ENV}.lab"
check_ingress_host_exists "prometheus.${TARGET_ENV}.lab"
check_ingress_host_exists "alertmanager.${TARGET_ENV}.lab"

echo
echo "Validating certificate readiness..."
check_certificate_ready "reposilite" "artifacts-tls"
check_certificate_ready "monitoring" "grafana-tls"
check_certificate_ready "monitoring" "prometheus-tls"
check_certificate_ready "monitoring" "alertmanager-tls"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Validation completed successfully for env=$TARGET_ENV"
  if [[ "$warnings" -gt 0 ]]; then
    echo "Warnings: $warnings"
  fi
  exit 0
fi

echo "Validation failed for env=$TARGET_ENV"
echo "Failures: $failures"
if [[ "$warnings" -gt 0 ]]; then
  echo "Warnings: $warnings"
fi
exit 1
