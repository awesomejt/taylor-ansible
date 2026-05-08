#!/usr/bin/env bash
# omlx-monitor.sh — Check both oMLX servers and alert on status transitions via Discord webhook.
# Deployed by Ansible to /usr/local/bin/omlx-monitor.sh on the Hermes host.
# Intended to run every 5 minutes via cron.
#
# State files: /var/lib/hermes-monitor/<hostname>.status  (contains "up" or "down")
# Log:         /var/log/hermes-monitor.log

set -euo pipefail

MODE="${1:-}"
if [[ -n "$MODE" && "$MODE" != "--heartbeat" ]]; then
  echo "Usage: $0 [--heartbeat]" >&2
  exit 2
fi

HEARTBEAT_MODE=false
if [[ "$MODE" == "--heartbeat" ]]; then
  HEARTBEAT_MODE=true
fi

SERVERS=(
  "macbook:http://192.168.50.93:8000"
  "macmini:http://192.168.50.94:8000"
)

STATE_DIR="/var/lib/hermes-monitor"
LOG_FILE="/var/log/hermes-monitor.log"
WEBHOOK_URL="${HERMES_OMLX_MONITOR_WEBHOOK:-}"
TIMEOUT=5  # seconds per curl attempt

mkdir -p "$STATE_DIR"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*" >> "$LOG_FILE"
}

send_alert() {
  local name="$1" status="$2" prev="$3"
  local emoji color msg
  if [[ "$status" == "up" ]]; then
    emoji=":white_check_mark:"
    color=3066993
    msg="**oMLX server \`${name}\` is back UP** (was: ${prev})"
  else
    emoji=":red_circle:"
    color=15158332
    msg="**oMLX server \`${name}\` is DOWN** (was: ${prev})"
  fi

  log "ALERT: $name transitioned $prev -> $status"

  if [[ -z "$WEBHOOK_URL" ]]; then
    log "WARNING: HERMES_OMLX_MONITOR_WEBHOOK not set — cannot send Discord alert"
    return
  fi

  local payload
  payload=$(printf '{"embeds":[{"title":"%s oMLX Server Status Change","description":"%s","color":%d}]}' \
    "$emoji" "$msg" "$color")

  curl -sf -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null || log "WARNING: webhook POST failed"
}

send_heartbeat() {
  local summary="$1" down_count="$2" color title

  if [[ "$down_count" -eq 0 ]]; then
    color=3066993
    title=":heartbeat: oMLX Daily Heartbeat (all healthy)"
  else
    color=15158332
    title=":warning: oMLX Daily Heartbeat (${down_count} down)"
  fi

  log "HEARTBEAT: daily summary generated (down=$down_count)"

  if [[ -z "$WEBHOOK_URL" ]]; then
    log "WARNING: HERMES_OMLX_MONITOR_WEBHOOK not set — cannot send Discord heartbeat"
    return
  fi

  local payload
  payload=$(printf '{"embeds":[{"title":"%s","description":"%s","color":%d}]}' \
    "$title" "$summary" "$color")

  curl -sf -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null || log "WARNING: webhook POST failed for heartbeat"
}

heartbeat_summary=""
heartbeat_down_count=0

for entry in "${SERVERS[@]}"; do
  name="${entry%%:*}"
  base_url="${entry#*:}"
  state_file="$STATE_DIR/${name}.status"

  prev_status="unknown"
  if [[ -f "$state_file" ]]; then
    prev_status="$(cat "$state_file")"
  fi

  # Probe /v1/models — returns 200 with JSON when the server is healthy
  if curl -sf --max-time "$TIMEOUT" \
       -H "Authorization: Bearer ${HERMES_OMLX_API_KEY:-amazing}" \
       "${base_url}/v1/models" >/dev/null 2>&1; then
    cur_status="up"
  else
    cur_status="down"
  fi

  # Write current state regardless (creates file on first run)
  echo -n "$cur_status" > "$state_file"

  if [[ "$cur_status" == "up" ]]; then
    heartbeat_summary+="- ${name}: UP\\n"
  else
    heartbeat_summary+="- ${name}: DOWN\\n"
    heartbeat_down_count=$((heartbeat_down_count + 1))
  fi

  if [[ "$HEARTBEAT_MODE" == "false" && "$cur_status" != "$prev_status" ]]; then
    send_alert "$name" "$cur_status" "$prev_status"
  else
    log "OK: $name is $cur_status (no change)"
  fi
done

if [[ "$HEARTBEAT_MODE" == "true" ]]; then
  send_heartbeat "$heartbeat_summary" "$heartbeat_down_count"
fi
