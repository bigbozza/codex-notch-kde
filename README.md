# Codex Quota for KDE Plasma

A Plasma 6 widget based on the information shown by
[CodexNotch](https://github.com/smallyunet/codex-notch). The panel view shows
the percentage of weekly Codex quota remaining. Clicking it opens a detailed
view with:

- ChatGPT plan
- Weekly quota remaining and reset progress
- Exact weekly reset date and a live countdown
- Purchased credit balance, when supplied by ChatGPT
- Available rate-limit reset credits and their next expiry, when supplied
- Manual refresh and an Open ChatGPT shortcut

<img width="410" height="372" alt="image" src="https://github.com/user-attachments/assets/54c149bb-195d-44f2-bd49-9fbb02af3a1f" />


## Requirements

- KDE Plasma 6
- Python 3
- Plasma's `plasma5support` package (installed by default on many Plasma 6 systems)
- A current Codex login in `~/.codex/auth.json`

The widget targets Plasma 6 and uses Plasma's compatibility data engine.

## Install

Run:

```bash
git clone https://github.com/bigbozza/codex-notch-kde.git ~/Applications/codex-notch-kde
cd ~/Applications/codex-notch-kde
./install.sh
```

Then add it to a panel or the desktop:

1. Right-click the panel or desktop and choose **Enter Edit Mode**.
2. Choose **Add Widgets**.
3. Search for **Codex Quota**.
4. Drag it beside the other widgets.

If it does not appear in the widget list immediately, restart Plasma once:

```bash
kquitapp6 plasmashell
kstart plasmashell
```

Running `./install.sh` again upgrades the installed copy after local changes.

To uninstall:

```bash
cd ~/Applications/codex-notch-kde
./uninstall.sh
```

## How it works

Every 60 seconds, Plasma's executable data engine launches the bundled Python
helper. The helper reads only `tokens.access_token` and `tokens.account_id`
from `$CODEX_HOME/auth.json`, or `~/.codex/auth.json` when `CODEX_HOME` is not
set. It makes a read-only request to:

```text
GET https://chatgpt.com/backend-api/wham/usage
```

If ChatGPT reports available reset credits, it also makes a best-effort
read-only request to the reset-credit details endpoint on the same host. The
helper returns only parsed display fields to the QML widget. It does not print
tokens, raw responses, prompts, conversation logs, or other session data, and
it does not store quota responses.

The ChatGPT usage endpoints are internal and may change. If that happens, the
widget keeps the last successful result visible and marks it as stale.

## Project layout

- `package/metadata.json`: Plasma package metadata
- `package/contents/ui/`: compact and expanded QML interface
- `package/contents/code/codex_usage.py`: authenticated read-only usage client
- `install.sh`: installs or upgrades the package with `kpackagetool6`
