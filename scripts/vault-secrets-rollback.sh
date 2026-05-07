#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   vault-secrets-rollback.sh <snapshot|snapshot.tar.gz> [repo_dir] [backup_root]
# Examples:
#   vault-secrets-rollback.sh 20260507-204500 "$HOME/ansible" "$HOME/.ansible-vault-backups"
#   vault-secrets-rollback.sh /path/to/20260507-204500.tar.gz

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <snapshot|snapshot.tar.gz> [repo_dir] [backup_root]" >&2
  exit 1
fi

SNAPSHOT_INPUT="$1"
REPO_DIR="${2:-$HOME/ansible}"
BACKUP_ROOT="${3:-$HOME/.ansible-vault-backups}"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "ERROR: repo directory not found: $REPO_DIR" >&2
  exit 1
fi

if [[ -f "$SNAPSHOT_INPUT" ]]; then
  SNAPSHOT_TAR="$SNAPSHOT_INPUT"
elif [[ -f "$BACKUP_ROOT/$SNAPSHOT_INPUT.tar.gz" ]]; then
  SNAPSHOT_TAR="$BACKUP_ROOT/$SNAPSHOT_INPUT.tar.gz"
else
  echo "ERROR: snapshot not found: $SNAPSHOT_INPUT" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

tar -C "$WORK_DIR" -xzf "$SNAPSHOT_TAR"

if [[ ! -f "$WORK_DIR/files.list" || ! -f "$WORK_DIR/sha256sums.txt" ]]; then
  echo "ERROR: snapshot missing files.list or sha256sums.txt: $SNAPSHOT_TAR" >&2
  exit 1
fi

(
  cd "$WORK_DIR/files"
  sha256sum -c "$WORK_DIR/sha256sums.txt" >/dev/null
)

BACKUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRE_TS="$(date -u +%Y%m%d-%H%M%S)"
"$BACKUP_SCRIPT_DIR/vault-secrets-backup.sh" "$REPO_DIR" "$BACKUP_ROOT" 45 >/tmp/vault-pre-restore-${PRE_TS}.log

while IFS= read -r rel_path; do
  src="$WORK_DIR/files/$rel_path"
  dst="$REPO_DIR/$rel_path"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
done < "$WORK_DIR/files.list"

echo "Rollback applied from: $SNAPSHOT_TAR"
echo "Pre-restore backup created (see latest tar in $BACKUP_ROOT)"
echo "Next step: run ansible syntax check before any apply"
