# homebrew-octavo

> **Disclaimer:** This repository is not associated with, endorsed by, or affiliated with any of the projects whose formulae it packages. It is created purely for the author's own use. There is no expectation of support from the author of this package, nor from the authors of the packages referenced herein. Use at your own risk.

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
| `aoe-dashboard` | Web dashboard service for Agent of Empires | [agent-of-empires/agent-of-empires](https://github.com/agent-of-empires/agent-of-empires) | Tagged — tracks upstream releases |
| `ccr-service` | `brew services` wrapper for claude-code-router (`ccr`) — installs CCR and runs its gateway + web UI as a background service | [musistudio/claude-code-router](https://github.com/musistudio/claude-code-router) | Tagged — tracks upstream releases |

After installing, follow each formula's caveats (`brew info coetzeer/homebrew-octavo/<formula>`) to wire the framework into its shell config.
