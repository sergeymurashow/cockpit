# Hammerspoon installer

This folder contains the installer for the Cockpit Hammerspoon setup.

What it does:

- installs the bundled `Hammerspoon.app` if the app is missing;
- falls back to Homebrew Cask only when no bundled app is present;
- backs up any existing `~/.hammerspoon`;
- copies this config into `~/.hammerspoon`;
- starts Hammerspoon.

Usage:

```bash
./installer/install.sh
```

Uninstall / restore:

```bash
./installer/uninstall.sh
```

Notes:

- The installer only manages Hammerspoon itself. The apps used by your layouts
  (Chrome, Slack, Teams, Telegram, Ghostty) are assumed to already be installed.
- All runtime dependencies used by the config are built into Hammerspoon.
