#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/.hammerspoon"

latest_backup="$(ls -dt "${HOME}"/.hammerspoon.backup.* 2>/dev/null | head -n 1 || true)"

if [[ -n "${latest_backup}" ]]; then
  rm -rf "${TARGET_DIR}"
  mv "${latest_backup}" "${TARGET_DIR}"
  echo "[uninstall] Restored backup from ${latest_backup}"
else
  rm -rf "${TARGET_DIR}"
  echo "[uninstall] Removed ${TARGET_DIR}"
fi
