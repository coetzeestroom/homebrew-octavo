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
| `clixad` | Free AI coding agent in your terminal, funded by rewarded ads | [clixad](https://clixad.io/) | npm — pinned registry release |

After installing, follow each formula's caveats (`brew info coetzeer/homebrew-octavo/<formula>`) to wire the framework into its shell config.
