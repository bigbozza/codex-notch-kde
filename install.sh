#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir="$project_dir/package"
package_id="com.boz.codexquota"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    printf 'kpackagetool6 was not found. Install KDE Plasma 6 development/package tools first.\n' >&2
    exit 1
fi

chmod +x "$package_dir/contents/code/codex_usage.py"

if kpackagetool6 --type Plasma/Applet --show "$package_id" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$package_dir"
else
    kpackagetool6 --type Plasma/Applet --install "$package_dir"
fi

printf 'Codex Quota is installed. Open Plasma Edit Mode, choose Add Widgets, and add "Codex Quota".\n'
