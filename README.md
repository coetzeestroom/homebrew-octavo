# homebrew-octavo

A Homebrew tap — a small cellar of formulae and casks, brewed in octavo (eight leaves to the sheet, perfectly pocket-sized).

## Usage

```bash
brew tap coetzeer/homebrew-octavo
brew trust coetzeer/octavo   # brew 6+ refuses untrusted taps; do this once
brew install oh-my-bash
```

## Layout

- `Formula/` — Ruby formulae for command-line tools
- `Casks/` — casks for GUI apps (when needed)

## Formulae

| Formula | Description | Upstream | Versioning |
|---|---|---|---|
| `oh-my-bash` | Bash framework: themes, plugins, aliases, completions | [ohmybash/oh-my-bash](https://github.com/ohmybash/oh-my-bash) | Untagged — pinned commit, date version, `livecheck` skipped |
| `oh-my-zsh` | Zsh framework: themes, plugins, completions | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) | Untagged — pinned commit, date version, `livecheck` skipped |
| `oh-my-fish` | Fish framework: packages, themes, `omf` CLI | [oh-my-fish/oh-my-fish](https://github.com/oh-my-fish/oh-my-fish) | Tagged — tracks upstream releases (v8) |
| `hermes-dashboard` | `brew services` wrapper for the Hermes Agent web dashboard | [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) | Tagged — tracks upstream releases |
| `ccr-service` | `brew services` wrapper for claude-code-router (`ccr`) — installs CCR and runs its gateway + web UI as a background service | [musistudio/claude-code-router](https://github.com/musistudio/claude-code-router) | Tagged — tracks upstream releases |

After installing, follow each formula's caveats (`brew info coetzeer/homebrew-octavo/<formula>`) to wire the framework into its shell config.

## Desktop apps (Pake/WebKitGTK windows)

These formulae compile a standalone Pake (Tauri/WebKitGTK) window around a local web UI. They require the host's WebKitGTK/GTK dev packages and a Rust toolchain (see `AGENTS.md`).

| Formula | Web UI | Port | Backend |
|---|---|---|---|
| `ccr-desktop` | Claude Code Router | 64720 | `ccr serve --no-open` (via `claude-code-router`) |
| `omnirouter-desktop` | OmniRouter | 64730 | `omnirouter` binary |
| `hermes-webui-desktop` | Hermes WebUI | 64740 | `server.py` from [nesquena/hermes-webui](https://github.com/nesquena/hermes-webui) (Python venv) |
| `herdr-desktop` | Herdr WebUI | 64750 | `herdr-webui --https off --backend-mode builtin` |
| `openwebui-desktop` | Open WebUI | 64760 | `open-webui serve --port 64760` (pip venv) |
| `hermes-workspace-desktop` | Hermes Workspace | 64770 | `server-entry.js` from [outsourc-e/hermes-workspace](https://github.com/outsourc-e/hermes-workspace) (bundled SSR server) |
| `deepseek-harness-desktop` | DeepSeek Harness | 64710/64711 | `dsh web` (npm) |

### Testing a formula locally

```bash
# Make sure the tap is up to date first:
brew update

# Install from the tap (builds from source). Note: a local file path like
# ./Formula/<formula>.rb does NOT work — Homebrew treats the argument as a
# tap name, not a file path.
HOMEBREW_NO_AUTO_UPDATE=1 brew install --build-from-source coetzeer/octavo/<formula>

# Run the formula's test block:
brew test coetzeer/octavo/<formula>

# Lint:
brew style Formula/<formula>.rb

# Uninstall when done:
brew uninstall coetzeer/octavo/<formula>
```

Notes:
- Pake formulae need the host WebKitGTK/GTK and Rust toolchain installed first (see `AGENTS.md` → "deepseek-harness-desktop").
- `openwebui-desktop` pulls a large Python venv; first install takes a while.
- Ports are fixed; avoid running two desktop apps that share a port (e.g. omnirouter 8080 vs openwebui 8081 are distinct).
