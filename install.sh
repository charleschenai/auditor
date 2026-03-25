#!/bin/bash
# Auditor — Claude Code Plugin Installer
# Installs or reinstalls the plugin into Claude Code's plugin system.
#
# Usage:
#   curl -fsSL <url>/install.sh | bash
#   # or after cloning:
#   bash install.sh

set -euo pipefail

PLUGIN_DIR="$HOME/.claude/plugins/marketplaces/auditor"
SETTINGS="$HOME/.claude/settings.json"
REPO_URL="${AUDITOR_REPO:-https://github.com/charleschenai/auditor.git}"

echo "=== Auditor Installer ==="

# 1. Clone or update the repo
if [ -d "$PLUGIN_DIR/.git" ]; then
    echo "Plugin already cloned at $PLUGIN_DIR, pulling latest..."
    cd "$PLUGIN_DIR" && git pull --ff-only 2>/dev/null || true
else
    echo "Cloning to $PLUGIN_DIR..."
    mkdir -p "$(dirname "$PLUGIN_DIR")"
    # Clean up any broken install
    rm -rf "$PLUGIN_DIR"
    git clone "$REPO_URL" "$PLUGIN_DIR"
fi

# 2. Verify required files exist
for f in plugin/.claude-plugin/plugin.json plugin/skills/audit/SKILL.md; do
    if [ ! -f "$PLUGIN_DIR/$f" ]; then
        echo "ERROR: Missing $f — clone may be corrupt"
        exit 1
    fi
done

# 3. Update settings.json
if [ ! -f "$SETTINGS" ]; then
    echo "Creating $SETTINGS..."
    mkdir -p "$(dirname "$SETTINGS")"
    cat > "$SETTINGS" << 'ENDJSON'
{
  "enabledPlugins": {
    "auditor@auditor": true
  },
  "extraKnownMarketplaces": {
    "auditor": {
      "source": {
        "source": "directory",
        "path": "PLUGIN_DIR_PLACEHOLDER"
      }
    }
  }
}
ENDJSON
    sed -i "s|PLUGIN_DIR_PLACEHOLDER|$PLUGIN_DIR|g" "$SETTINGS"
else
    # Check if python3 is available for JSON manipulation
    if command -v python3 &>/dev/null; then
        python3 << PYEOF
import json, sys

settings_path = "$SETTINGS"
plugin_dir = "$PLUGIN_DIR"

with open(settings_path, "r") as f:
    settings = json.load(f)

changed = False

# Add enabledPlugins
if "enabledPlugins" not in settings:
    settings["enabledPlugins"] = {}
if "auditor@auditor" not in settings.get("enabledPlugins", {}):
    settings["enabledPlugins"]["auditor@auditor"] = True
    changed = True

# Add extraKnownMarketplaces
if "extraKnownMarketplaces" not in settings:
    settings["extraKnownMarketplaces"] = {}
if "auditor" not in settings.get("extraKnownMarketplaces", {}):
    settings["extraKnownMarketplaces"]["auditor"] = {
        "source": {
            "source": "directory",
            "path": plugin_dir
        }
    }
    changed = True

if changed:
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
    print("Updated settings.json")
else:
    print("settings.json already configured")
PYEOF
    else
        echo "WARNING: python3 not found — please add these entries to $SETTINGS manually:"
        echo ""
        echo '  "enabledPlugins": { "auditor@auditor": true }'
        echo '  "extraKnownMarketplaces": { "auditor": { "source": { "source": "directory", "path": "'$PLUGIN_DIR'" } } }'
    fi
fi

echo ""
echo "=== Installed successfully ==="
echo "Restart Claude Code to pick up the plugin."
echo "Then type /audit <repo> [goal] to run an audit."
