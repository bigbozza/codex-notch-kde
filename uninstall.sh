#!/usr/bin/env bash
set -euo pipefail

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    printf 'kpackagetool6 was not found.\n' >&2
    exit 1
fi

kpackagetool6 --type Plasma/Applet --remove com.boz.codexquota
printf 'Codex Quota was removed from your Plasma widget packages.\n'
