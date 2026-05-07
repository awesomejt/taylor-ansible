#!/bin/bash

set -euo pipefail

usage() {
    cat << 'EOF'
Usage: sync-to-ansible.sh [host_or_user@host] [remote_path] [--delete] [--dry-run]

Defaults:
    host_or_user@host: jason@192.168.50.11
  remote_path: ~/ansible

Path rules:
  /path      -> absolute path on remote host
  ~/path     -> path under remote user's home
  my-folder  -> treated as ~/my-folder

Environment overrides:
    ANSIBLE_SYNC_HOST  (default: 192.168.50.11)
    ANSIBLE_SYNC_USER  (default: jason)
  ANSIBLE_SYNC_DEST  (default: ~/ansible)

Examples:
  ./sync-to-ansible.sh jason@192.168.50.11
  ./sync-to-ansible.sh 192.168.50.11
  ./sync-to-ansible.sh jason@192.168.50.11 ansible --delete
  ANSIBLE_SYNC_HOST=192.168.50.11 ./sync-to-ansible.sh

Git Bash fallback:
  If rsync is missing on Git Bash for Windows, this script falls back to
  tar-over-ssh sync. In fallback mode, --delete is not supported.
EOF
}

require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Missing required command: ${cmd}"
        exit 1
    fi
}

is_git_bash_windows() {
    local os_name
    os_name="$(uname -s 2>/dev/null || true)"

    case "${os_name}" in
        MINGW*|MSYS*|CYGWIN*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

print_rsync_install_hint_git_bash() {
    cat << 'EOF'
rsync is not installed in this Git Bash environment.

To install rsync on Windows:
1) Install MSYS2.
2) Open an MSYS2 UCRT64 shell and run:
   pacman -Syu
   pacman -S rsync
3) Run this script from MSYS2, or add C:\msys64\usr\bin to your PATH.
EOF
}

normalize_remote_dest() {
    if [[ "${REMOTE_DEST}" == *"'"* ]]; then
        echo "Remote path cannot contain single quote characters: ${REMOTE_DEST}"
        exit 1
    fi

    if ! [[ "${REMOTE_DEST}" =~ ^[A-Za-z0-9._~/-]+$ ]]; then
        echo "Remote path contains unsupported characters: ${REMOTE_DEST}"
        echo "Allowed characters: letters, numbers, ., _, -, /, ~"
        exit 1
    fi

    if [[ "${REMOTE_DEST}" == *"~"* ]] && [[ "${REMOTE_DEST}" != "~" ]] && [[ "${REMOTE_DEST}" != "~/"* ]]; then
        echo "Tilde (~) is only supported as '~' or '~/path': ${REMOTE_DEST}"
        exit 1
    fi

    if [[ "${REMOTE_DEST}" != /* ]] && [[ "${REMOTE_DEST}" =~ (^|/)\.\.(/|$) ]]; then
        echo "Home-relative remote path cannot contain '..': ${REMOTE_DEST}"
        exit 1
    fi

    if [ "${REMOTE_DEST}" = "~" ] || [ "${REMOTE_DEST}" = "~/" ]; then
        REMOTE_DEST="~"
    elif [[ "${REMOTE_DEST}" == "~/"* ]]; then
        :
    elif [[ "${REMOTE_DEST}" == /* ]]; then
        :
    else
        REMOTE_DEST="~/${REMOTE_DEST#./}"
    fi
}

ensure_remote_dest_exists() {
    if [ "${REMOTE_DEST}" = "~" ]; then
        ssh "${REMOTE_TARGET}" 'mkdir -p "$HOME"'
    elif [[ "${REMOTE_DEST}" == "~/"* ]]; then
        local remote_suffix
        remote_suffix="${REMOTE_DEST:2}"
        ssh "${REMOTE_TARGET}" "mkdir -p \"\$HOME/${remote_suffix}\""
    else
        ssh "${REMOTE_TARGET}" "mkdir -p '${REMOTE_DEST}'"
    fi
}

print_resolved_remote_dest() {
    if [ "${REMOTE_DEST}" = "~" ]; then
        ssh "${REMOTE_TARGET}" 'printf "%s\n" "$HOME"'
    elif [[ "${REMOTE_DEST}" == "~/"* ]]; then
        local remote_suffix
        remote_suffix="${REMOTE_DEST:2}"
        ssh "${REMOTE_TARGET}" "printf '%s\\n' \"\$HOME/${remote_suffix}\""
    else
        printf '%s\n' "${REMOTE_DEST}"
    fi
}

verify_remote_dest_exists() {
    if [ "${REMOTE_DEST}" = "~" ]; then
        ssh "${REMOTE_TARGET}" 'test -d "$HOME"'
    elif [[ "${REMOTE_DEST}" == "~/"* ]]; then
        local remote_suffix
        remote_suffix="${REMOTE_DEST:2}"
        ssh "${REMOTE_TARGET}" "test -d \"\$HOME/${remote_suffix}\""
    else
        ssh "${REMOTE_TARGET}" "test -d '${REMOTE_DEST}'"
    fi
}

resolve_remote_dest_for_rsync() {
    if [ "${REMOTE_DEST}" = "~" ]; then
        ssh "${REMOTE_TARGET}" 'printf "%s" "$HOME"'
    elif [[ "${REMOTE_DEST}" == "~/"* ]]; then
        local remote_suffix
        remote_suffix="${REMOTE_DEST:2}"
        ssh "${REMOTE_TARGET}" "printf '%s' \"\$HOME/${remote_suffix}\""
    else
        printf '%s' "${REMOTE_DEST}"
    fi
}

sync_with_rsync() {
    local rsync_remote_dest
    local rsync_args=(
        -avz
        --progress
        "--exclude=/${SCRIPT_NAME}"
        --exclude=.git/
        --exclude=.DS_Store
        --exclude=*.swp
        --exclude=temp/
    )

    if [ "${DELETE_REMOTE}" = "true" ]; then
        rsync_args+=(--delete)
    fi

    if [ "${DRY_RUN}" = "true" ]; then
        rsync_args+=(--dry-run)
    fi

    ensure_remote_dest_exists
    rsync_remote_dest="$(resolve_remote_dest_for_rsync)"
    rsync "${rsync_args[@]}" "${SCRIPT_DIR}/" "${REMOTE_TARGET}:${rsync_remote_dest}/"
}

sync_with_git_bash_fallback() {
    local tar_excludes=(
        "--exclude=${SCRIPT_NAME}"
        --exclude=.git
        --exclude=.DS_Store
        --exclude=*.swp
        --exclude=temp/
    )

    if [ "${DELETE_REMOTE}" = "true" ]; then
        echo "--delete is not supported in Git Bash fallback mode (tar-over-ssh)."
        echo "Install rsync to use --delete."
        print_rsync_install_hint_git_bash
        exit 1
    fi

    require_cmd tar

    if [ "${DRY_RUN}" = "true" ]; then
        echo "Dry run (Git Bash fallback): files that would be transferred"
        (
            cd "${SCRIPT_DIR}"
            tar "${tar_excludes[@]}" -cf - . | tar -tf -
        )
        return 0
    fi

    if [ "${REMOTE_DEST}" = "~" ]; then
        (
            cd "${SCRIPT_DIR}"
            tar "${tar_excludes[@]}" -czf - .
        ) | ssh "${REMOTE_TARGET}" 'mkdir -p "$HOME" && tar -xzf - -C "$HOME"'
    elif [[ "${REMOTE_DEST}" == "~/"* ]]; then
        local remote_suffix
        remote_suffix="${REMOTE_DEST:2}"
        (
            cd "${SCRIPT_DIR}"
            tar "${tar_excludes[@]}" -czf - .
        ) | ssh "${REMOTE_TARGET}" "mkdir -p \"\$HOME/${remote_suffix}\" && tar -xzf - -C \"\$HOME/${remote_suffix}\""
    else
        (
            cd "${SCRIPT_DIR}"
            tar "${tar_excludes[@]}" -czf - .
        ) | ssh "${REMOTE_TARGET}" "mkdir -p '${REMOTE_DEST}' && tar -xzf - -C '${REMOTE_DEST}'"
    fi
}

DEFAULT_HOST="${ANSIBLE_SYNC_HOST:-192.168.50.11}"
DEFAULT_USER="${ANSIBLE_SYNC_USER:-jason}"
DEFAULT_DEST="${ANSIBLE_SYNC_DEST:-~/ansible}"

TARGET_ARG=""
REMOTE_DEST="${DEFAULT_DEST}"
DELETE_REMOTE="false"
DRY_RUN="false"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --delete)
            DELETE_REMOTE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [ -z "${TARGET_ARG}" ]; then
                TARGET_ARG="$1"
            elif [ "${REMOTE_DEST}" = "${DEFAULT_DEST}" ]; then
                REMOTE_DEST="$1"
            else
                echo "Unexpected argument: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -n "${TARGET_ARG}" ]; then
    if [[ "${TARGET_ARG}" == *"@"* ]]; then
        REMOTE_TARGET="${TARGET_ARG}"
    else
        if [ -z "${DEFAULT_USER}" ]; then
            echo "Unable to determine remote user. Set ANSIBLE_SYNC_USER or pass user@host."
            exit 1
        fi
        REMOTE_TARGET="${DEFAULT_USER}@${TARGET_ARG}"
    fi
else
    if [ -z "${DEFAULT_USER}" ]; then
        echo "Unable to determine remote user. Set ANSIBLE_SYNC_USER or pass user@host."
        exit 1
    fi

    REMOTE_TARGET="${DEFAULT_USER}@${DEFAULT_HOST}"
fi

normalize_remote_dest

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

require_cmd ssh

echo "Sync source : ${SCRIPT_DIR}/"
echo "Sync target : ${REMOTE_TARGET}:${REMOTE_DEST}/"

if command -v rsync >/dev/null 2>&1; then
    sync_with_rsync
else
    if is_git_bash_windows; then
        echo "rsync not found in Git Bash; using tar-over-ssh fallback"
        print_rsync_install_hint_git_bash
        sync_with_git_bash_fallback
    else
        echo "Missing required command: rsync"
        echo "Install rsync to continue."
        exit 1
    fi
fi

if [ "${DRY_RUN}" = "false" ]; then
    if verify_remote_dest_exists; then
        RESOLVED_REMOTE_DEST="$(print_resolved_remote_dest)"
        echo "Remote destination verified: ${RESOLVED_REMOTE_DEST}"
    else
        echo "Sync completed, but remote destination directory was not found: ${REMOTE_DEST}"
        exit 1
    fi
fi

echo "Sync complete"
