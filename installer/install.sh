#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${HOME}/.hammerspoon"
BUNDLED_APP="${SOURCE_DIR}/Hammerspoon.app"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${HOME}/.hammerspoon.backup.${TIMESTAMP}"

log() {
  printf '[install] %s\n' "$*"
}

have_hammerspoon() {
  [[ -d /Applications/Hammerspoon.app ]] || [[ -d "${HOME}/Applications/Hammerspoon.app" ]]
}

install_hammerspoon() {
  if have_hammerspoon; then
    log "Hammerspoon already installed"
    return
  fi

  if [[ -d "${BUNDLED_APP}" ]]; then
    log "Installing bundled Hammerspoon.app"
    ditto "${BUNDLED_APP}" "/Applications/Hammerspoon.app"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    log "Hammerspoon not found; installing via Homebrew Cask"
    brew install --cask hammerspoon
    return
  fi

  cat <<'EOF'
[install] Hammerspoon is not installed and Homebrew was not found.
Install Hammerspoon manually from https://www.hammerspoon.org/ or install Homebrew and rerun this installer.
EOF
  exit 1
}

backup_existing_config() {
  if [[ ! -d "${TARGET_DIR}" ]]; then
    return
  fi

  if [[ -L "${TARGET_DIR}" ]] || [[ -f "${TARGET_DIR}" ]]; then
    log "Target exists but is not a directory; moving it aside"
    mv "${TARGET_DIR}" "${BACKUP_DIR}"
    return
  fi

  if [[ -n "$(ls -A "${TARGET_DIR}" 2>/dev/null || true)" ]]; then
    log "Backing up existing config to ${BACKUP_DIR}"
    mv "${TARGET_DIR}" "${BACKUP_DIR}"
  fi
}

deploy_config() {
  mkdir -p "${TARGET_DIR}"

  rsync -a \
    --exclude '.git' \
    --exclude '.agents' \
    --exclude '.codex' \
    --exclude 'Hammerspoon.app' \
    --exclude 'Cockpit-installer*.zip' \
    --exclude 'installer' \
    --exclude 'cfg_bkp' \
    "${SOURCE_DIR}/" \
    "${TARGET_DIR}/"
}

start_hammerspoon() {
  open -a Hammerspoon || true
}

install_hammerspoon

if [[ "${SOURCE_DIR}" != "${TARGET_DIR}" ]]; then
  backup_existing_config
  deploy_config
else
  log "Source and target are the same directory; skipping copy"
fi

start_hammerspoon

cat <<EOF
[install] Done.
[install] Config deployed to ${TARGET_DIR}
[install] If Hammerspoon asks for Accessibility permissions, grant them and restart it.
EOF
