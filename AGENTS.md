# AGENTS.md — homebrew-octavo

A Homebrew **tap** (custom repository of formulae) distributing upstream shell frameworks (`oh-my-zsh`, `oh-my-bash`, `oh-my-fish`) via `brew install`.

## Project structure

```
Formula/
├── oh-my-zsh.rb    # ohmyzsh/ohmyzsh — untagged, pinned commit
├── oh-my-bash.rb   # ohmybash/oh-my-bash — untagged, pinned commit
├── oh-my-fish.rb   # oh-my-fish/oh-my-fish — tagged releases (v8+)
└── hermes-dashboard.rb  # NousResearch/hermes-agent — tagged releases (v2026.8.31+), brew services wrapper
```

## Essential commands

| Command | What it does |
|---|---|
| `brew style <formula.rb>` | Lint a formula (Homebrew's RuboCop) |
| `brew audit --new-formula <formula.rb>` | New-formula audit |
| `brew install --build-from-source <formula.rb>` | Install from local source |
| `brew test --HEAD <formula>` | Run the formula's `test do` block |
| `brew bump --open-pr --formulae --tap=coetzeer/homebrew-octavo` | Bump all formulae via autobump |
| `brew bump --open-pr <formula>` | Bump a single formula |

## How each formula works

All four formulae follow the same pattern:

1. `url` points to a GitHub archive tarball (commit hash for untagged projects, tag for tagged).
2. `sha256` is the corresponding tarball checksum.
3. `install` copies everything into `libexec` (or generates the service file for wrappers).
4. Each formula prints `caveats` showing how to source the framework from the user's shell config.
5. `test do` runs the framework's init script in a non-interactive shell and checks a known output value.

### Versioning

- **oh-my-zsh** and **oh-my-bash**: upstream doesn't tag releases. Version is the commit date (`YYYY-MM-DD` format). `livecheck` is explicitly skipped. Updating means picking a new commit hash, computing the tarball checksum, and setting version to the commit date.
- **oh-my-fish** and **hermes-dashboard**: upstream tags releases. Version follows the upstream tag. Homebrew auto-detects tags via `livecheck`.

### Install pattern

```ruby
def install
  libexec.install Dir["*"]
end
```

Shell frameworks use `libexec.install Dir["*"]` — never `prefix.install` or `bin.install`. The frameworks are sourced by the user's shell, not symlinked into PATH.

**`hermes-dashboard` is an exception**: it uses the `service` block to define a `brew services`-managed process (generates a launchd plist on macOS, a systemd unit on Linux) rather than downloading and installing source code. The `url` is a formality pointing to the upstream hermes-agent repo.

### Caveats pattern

Shell framework formulae have a `caveats` block that tells the user:
1. Which shell config file to edit (`.zshrc`, `.bashrc`, `config.fish`).
2. The exact `export`/`set` and `source` lines to add.
3. How to disable the framework's built-in auto-updater (since Homebrew manages updates).
4. Where runtime data goes (read-only Cellar workaround).

**`hermes-dashboard`**: caveats show `brew services start/stop/restart` commands.

## Convention: pin commit hashes with `git-synced`

When updating untagged formulae (oh-my-zsh, oh-my-bash), the commit hash used in the `url` must match a commit from the upstream repository's default branch. The autobump workflow uses `--bump-synced` to enforce this.

## Gotchas

- **LSP type errors on formula files are normal**: Homebrew's Ruby DSL (`desc`, `homepage`, `url`, `sha256`, `libexec`, `opt_libexec`, `shell_output`, `livecheck`, `prefix`, `opt_prefix`, etc.) is not resolvable by standard Ruby LSP. The project diagnostics shown by LSP are expected and harmless.
- **`brew style` is strict**: Homebrew enforces RuboCop rules. A common violation is line length in test blocks — wrap long lines with `\` continuation or split into multiple lines.
- **`brew test --HEAD` requires the formula to be installed**: `brew test` won't work on an uninstalled formula. Use `brew install --build-from-source` first, then `brew test`.
- **oh-my-fish upgrades wipe user-installed packages**: Since `omf install` writes into `$OMF_PATH/pkg` (which is inside the Homebrew keg), `brew upgrade oh-my-fish` removes them. The caveats warn about this.
- **`brew trust` needed on brew 6+**: `brew tap coetzeer/homebrew-octavo` must be followed by `brew trust coetzeer/octavo` once, or installs will be refused.
- **Commit messages use a specific format**: Untagged formula updates use `"Update <formula> to <abbreviated commit> (<date>)"` e.g. `"Update oh-my-zsh to commit 8a5b3930 (2026-09-06)"`.
- **`hermes-dashboard` depends on `hermes-agent`**: The `depends_on "hermes-agent"` line requires `hermes-agent` to exist as a formula in the same tap or another tapped repository. If it's not yet added, `brew install hermes-dashboard` will fail with a "no available formula" error — the dependency is declared preemptively.
- **`hermes-dashboard` uses `service` block**: The `brew services` system generates a launchd plist on macOS and a systemd unit on Linux. The `environment_variables` and `run` paths use `Dir.home` evaluated at formula load time, so the service file is baked with the full absolute path for the user running `brew services start`.
- **`hermes-dashboard` uses `std_service_path_env`**: The PATH includes Homebrew's standard service path via `std_service_path_env` helper, prepended with the hermes-agent venv and node binary paths.

## CI/CD

- **tests.yml**: Runs `brew test-bot` on `macos-26` and `ubuntu-latest` (inside Homebrew container). Runs on every PR and push to `main`. Tests tap syntax and formula installation.
- **autobump.yml**: Scheduled daily at 14:10 UTC. Runs `brew bump --no-fork --open-pr` to auto-update formulae. Only triggers on PR merge to `main` or schedule.
- **dependabot.yml**: Weekly updates for GitHub Actions. Pinned to `@v6.1.0` for cache, `@v7.0.1` for upload-artifact.
- **publish.yml**: Removed (kept in `.github/removed/` for reference). Not active.

## Shell config

CI workflows use `bash -xeuo pipefail {0}` shell. All formulae use `shell_output(...)` for test commands, typically with `2>/dev/null` to suppress framework chatter.