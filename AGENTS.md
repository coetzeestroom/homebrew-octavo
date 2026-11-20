# AGENTS.md — homebrew-octavo

A Homebrew **tap** (custom repository of formulae) distributing upstream shell frameworks (`oh-my-zsh`, `oh-my-bash`, `oh-my-fish`) via `brew install`, plus `brew services` wrappers (`hermes-dashboard`, `ccr-service`), and the Pake desktop wrappers (`deepseek-harness-desktop`, `hermes-webui-desktop`, `hermes-workspace-desktop`).

## Project structure

```
Formula/
├── oh-my-zsh.rb    # ohmyzsh/ohmyzsh — untagged, pinned commit
├── oh-my-bash.rb   # ohmybash/oh-my-bash — untagged, pinned commit
├── oh-my-fish.rb   # oh-my-fish/oh-my-fish — tagged releases (v8+)
├── hermes-dashboard.rb  # NousResearch/hermes-agent — tagged releases (v2026.8.31+), brew services wrapper
├── ccr-service.rb  # musistudio/claude-code-router — tagged releases (v3.1.3+), brew services wrapper; depends on homebrew-core's claude-code-router
├── deepseek-harness-desktop.rb  # @deepseek-ai/dsh npm tarball — Pake/Tauri window around `dsh web`; Linux only
├── kilo-desktop.rb  # Kilo-Org/kilo-desktop .deb — repackaged Electron app; Linux amd64 only
├── hermes-webui-desktop.rb  # nesquena/hermes-webui — Pake window around the Python WebUI; Linux only
├── hermes-workspace-desktop.rb  # outsourc-e/hermes-workspace — Pake window around the TanStack Start SSR server; Linux only
├── ccr-desktop.rb  # STUB: desktop window for Claude Code Router web UI (to be completed)
├── omnirouter-desktop.rb  # STUB: desktop window for OmniRouter web UI (to be completed)
├── herdr-desktop.rb  # STUB: desktop window for Herdr web UI (to be completed)
└── openwebui-desktop.rb  # STUB: desktop window for Open WebUI (to be completed)
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

All formulae follow the same pattern:

1. `url` points to a GitHub archive tarball (commit hash for untagged projects, tag for tagged).
2. `sha256` is the corresponding tarball checksum.
3. `install` copies everything into `libexec` (or generates the service file for wrappers).
4. Each formula prints `caveats` showing how to source the framework from the user's shell config.
5. `test do` runs the framework's init script in a non-interactive shell and checks a known output value.

### Versioning

- **oh-my-zsh** and **oh-my-bash**: upstream doesn't tag releases. Version is the commit date (`YYYY-MM-DD` format). `livecheck` is explicitly skipped. Updating means picking a new commit hash, computing the tarball checksum, and setting version to the commit date.
- **oh-my-fish**, **hermes-dashboard**, **ccr-service**, **hermes-webui-desktop**, and **hermes-workspace-desktop**: upstream tags releases. Version follows the upstream tag. Homebrew auto-detects tags via `livecheck`.
- **deepseek-harness-desktop**: version tracks the npm `latest` dist-tag of `@deepseek-ai/dsh` exactly. `url` is the registry tarball (`https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-<version>.tgz`) and `livecheck` reads `version` from `https://registry.npmjs.org/@deepseek-ai/dsh/latest` with the `:json` strategy. The dedicated `bump-deepseek-harness-desktop.yml` workflow opens the bump PR.
- **kilo-desktop**: version tracks **stable** GitHub releases of `Kilo-Org/kilo-desktop` (the frequent `-preview-` tags are marked prerelease and ignored). `url` points at the versioned amd64 `.deb` asset, `livecheck` uses `strategy :github_latest` on `https://github.com/Kilo-Org/kilo-desktop/releases/latest`, and the version is inferred from the URL (do not add a `version` line). The dedicated `bump-kilo-desktop.yml` workflow opens the bump PR.

### Install pattern

```ruby
def install
  libexec.install Dir["*"]
end
```

Shell frameworks use `libexec.install Dir["*"]` — never `prefix.install` or `bin.install`. The frameworks are sourced by the user's shell, not symlinked into PATH.

**`hermes-dashboard` and `ccr-service` are exceptions**: they use the `service` block to define a `brew services`-managed process (generates a launchd plist on macOS, a systemd unit on Linux) rather than downloading and installing source code. The `url` is a formality pointing to the upstream repo. `hermes-dashboard` depends on `hermes-agent` (not yet in the tap); `ccr-service` depends on `claude-code-router` from homebrew-core, which installs the `ccr` npm CLI.

### Caveats pattern

Shell framework formulae have a `caveats` block that tells the user:
1. Which shell config file to edit (`.zshrc`, `.bashrc`, `config.fish`).
2. The exact `export`/`set` and `source` lines to add.
3. How to disable the framework's built-in auto-updater (since Homebrew manages updates).
4. Where runtime data goes (read-only Cellar workaround).

**`hermes-dashboard` and `ccr-service`**: caveats show `brew services start/stop/restart` commands plus the service's listening ports.

### deepseek-harness-desktop (Pake window)

This formula is the only one that compiles a native app during `brew install`:

1. `system "npm", "install", *std_npm_args` installs `@deepseek-ai/dsh` into `libexec/lib/node_modules`, and `bin.install_symlink libexec/"bin/dsh"` exposes the CLI on `PATH`.
2. The icon is copied from `dsh-web-frontend/dist/icon-512.png` inside the npm tree.
3. `pake http://127.0.0.1:64711/ --no-bundle ...` compiles the Tauri/WebKitGTK binary; the resulting `*-binary` is installed as `libexec/deepseek-harness-app`.
4. `libexec/auth-redirect.mjs` is a loopback sidecar, and `bin/deepseek-harness-desktop` is a bash wrapper that starts `dsh web`, waits for its printed `?token=` URL, starts the sidecar, launches the window, and kills all of them on exit.

Lifecycle details worth remembering:

- **Auth cannot be disabled.** `dsh web` mints a random per-process launch token and prints `http://127.0.0.1:<port>/?token=<token>`. Only that URL (or a signed cookie backed by `$DSH_HOME/.credentials.yaml`) is accepted; plain `/` returns HTTP 401. Pake bakes its URL at compile time, so the redirect sidecar serves the stale URL and 302s the window to the freshly printed one.
- **`dsh web` must use `--no-open`**, otherwise it also opens the system browser.
- **The sidecar port is baked in** (`64711`); the web port can be overridden at runtime with `DSH_DESKTOP_PORT` (default `64710`). Both defaults sit above the Linux ephemeral range (32768-60999).
- **`flock` on `${XDG_RUNTIME_DIR:-$TMPDIR}/deepseek-harness-desktop-$UID.lock`** refuses a second concurrent launch.
- **`--multi-window`, `--no-restore-last-url`** keep the window pointing at the redirect sidecar instead of restoring a stale URL.
- The desktop entry is linked into `~/.local/share/applications` via `post_install_steps` (`mkdir_p` + `symlink`) because Homebrew 7 rejects the legacy `post_install` method.

**System build prerequisites are deliberately not Homebrew dependencies.** Tauri links against the host's WebKitGTK/GTK stack, and bottling 2 GB of WebKit into the tap is undesirable. Homebrew's `rust` keg also drags in LLVM, so Rust is treated the same way. `check_system_dependencies!` runs first in `install`, checks `REQUIRED_PKG_CONFIG_MODULES` (`gtk+-3.0`, `javascriptcoregtk-4.1`, `libsoup-3.0`, `librsvg-2.0`, `openssl`, `webkit2gtk-4.1`) with the host `/usr/bin/pkg-config`, checks for `cargo`/`rustc` >= `RUST_MIN_VERSION` (1.77), and `odie`s with the commands for `/etc/os-release`:

```sh
# Arch / CachyOS / EndeavourOS / Manjaro
sudo pacman -S --needed base-devel webkit2gtk-4.1 gtk3 librsvg libayatana-appindicator openssl xdotool rust curl wget file

# Debian / Ubuntu / Mint / Pop!_OS
sudo apt update && sudo apt install -y build-essential pkg-config libwebkit2gtk-4.1-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev libxdo-dev rustc cargo curl wget file

# Fedora / RHEL / Rocky / Alma
sudo dnf install -y webkit2gtk4.1-devel openssl-devel libappindicator-gtk3-devel librsvg2-devel libxdo-devel gcc gcc-c++ make pkgconf-pkg-config rust cargo curl wget file

# openSUSE
sudo zypper install -y webkit2gtk4.1-devel libopenssl-devel libayatana-appindicator3-devel librsvg-devel libxdo-devel gcc gcc-c++ make pkg-config rust cargo curl wget file
```

Those libraries are needed at run time too, so they must not be removed after the build. `libappindicator-gtk3` does not exist on CachyOS; `libayatana-appindicator` is the package there. A rustup toolchain works too (`install` prepends `dirname(cargo)` to the build `PATH`), but the version check still runs.

### kilo-desktop (deb repack)

This formula does not build or wrap anything: it downloads the official amd64 `.deb` from the upstream GitHub release and repackages it.

1. `ar x cached_download` unpacks the Debian archive, then `tar -xf data.tar.*` expands it (`binutils` and `xz` are build dependencies).
2. The contents of `usr/lib/kilo-desktop` are installed into `libexec`; `bin/kilo-desktop` is a two-line launcher that `exec`s `#{opt_libexec}/kilo-desktop --no-sandbox "$@"`.
3. The 1024×1024 icon is installed under `share/icons/hicolor`, and a desktop entry with an absolute `Exec`/`Icon` is written to `share/applications` and linked into `~/.local/share/applications` via `post_install_steps`.

Things to remember:

- **Sandbox**: the deb ships `chrome-sandbox` mode `0755` and has no `postinst`, and Homebrew cannot make it setuid root, so `--no-sandbox` is required on distros that restrict unprivileged user namespaces (Ubuntu 23.10+).
- **Host runtime libraries**: GTK 3, NSS, libsecret, libnotify and AT-SPI are treated as system prerequisites (like the Pake formulae) rather than Homebrew dependencies, to avoid a large GUI dependency graph.
- **No bottle**: the download is ~314 MB and the installed keg is ~1.5 GB, so the formula installs from source and `test-kilo-desktop.yml` only installs and tests.
- **Stable channel only**: upstream publishes preview builds several times a day; they are marked prerelease on GitHub and deliberately ignored.
- **No `version` line**: Homebrew detects `1.0.0` from the asset filename, and an explicit `version` fails `brew audit` as redundant. For the same reason the bump workflow calls `brew bump-formula-pr` with `--url` but **without** `--version`.
- **`--version` is not a version probe**: running `kilo-desktop --version` boots the full app. The `test do` block checks files only.

### hermes-webui-desktop (Pake window)

Wraps `nesquena/hermes-webui`, a dependency-light Python server (`server.py` + `api/` + `static/`) with no build step:

1. Only the runtime files are installed into `libexec`; docs, tests, container files and Nix expressions stay out of the bottle.
2. `virtualenv_create(libexec/".venv", "python@3.13")` plus the `pyyaml` resource provide the only hard dependency. The venv is named `.venv` on purpose: `api/config.py` resolves `REPO_ROOT/.venv` when it looks for a Python interpreter.
3. `pake http://127.0.0.1:64740/ ...` compiles the window, and `bin/hermes-webui-desktop` starts `server.py`, waits for the port, launches the window, and kills the server when the window closes.
4. `test do` boots `server.py` on a free port and asserts `GET /health` returns 200, so CI exercises the real payload before the bottle is built.

Notes:

- `cryptography` (upstream's optional passkey/WebAuthn support) is deliberately not bundled — building it from source needs Rust. Password auth via `HERMES_WEBUI_PASSWORD` works without it.
- Chat needs a running Hermes Agent gateway; the UI starts without one and reports the agent as offline.
- Session state follows upstream defaults (`~/.hermes`) unless `HERMES_WEBUI_STATE_DIR` is set.

### hermes-workspace-desktop (Pake window)

Wraps `outsourc-e/hermes-workspace`, a TanStack Start (Vite) app. `install` is the heaviest build in the tap:

1. `pnpm install --frozen-lockfile` with explicit `--allow-build` flags. pnpm 12 aborts with `ERR_PNPM_IGNORED_BUILDS` unless every scripted dependency was classified: `esbuild` and `unrs-resolver` are allowed, `electron`/`electron-winstaller` are denied. `--store-dir` keeps the store inside `buildpath`.
2. `pnpm build` writes `dist/client` (static assets) and `dist/server` (the SSR handler).
3. `pnpm exec esbuild server-entry.js --bundle --format=esm --banner:js=...` bundles the SSR server and every runtime dependency into `libexec/server.mjs` (~21 MB). Shipping `node_modules` instead would be ~1 GB. The banner installs a real `require` via `createRequire`, because CJS dependencies (`react-dom`) call `require` for Node builtins and plain ESM output crashes on them.
4. The window points at `http://127.0.0.1:64770/`; the wrapper runs `node server.mjs` with `HOST=127.0.0.1`, `PORT`, `NODE_ENV=production` and `cd`s into `libexec` so `skills/` resolves.
5. `test do` boots `server.mjs` on a free port and asserts `GET /` returns 200.

Notes:

- `server-entry.js` is upstream's Node HTTP wrapper around `dist/server/server.js`. `node dist/server/server.js` exits immediately and `package.json`'s `start` script still points at a stale `.output/server/index.mjs`, so always go through `server-entry.js`.
- The Workspace is a control plane for a Hermes Agent gateway: `HERMES_API_URL` (default `http://127.0.0.1:8642`) and `HERMES_DASHBOARD_URL` (default `http://127.0.0.1:9119`). Without a gateway the window still opens and reports the agent as offline.

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
- **`ccr-service` depends on homebrew-core's `claude-code-router`**: The wrapper adds only the `service` block; the dependency installs the `ccr` npm CLI (requires `node`). The service runs `ccr serve --no-open` in the foreground (management UI on port 3458, model gateway on port 3456). `ccr start` must NOT be used in the service block — it daemonizes and would exit, causing a restart loop under `keep_alive`.
- **Wrapper formulae need a real file in the keg**: Brew's empty-installation check ignores `INSTALL_RECEIPT.json`, so writing that file does not prevent "Empty installation" failures in `brew test-bot`. `ccr-service` installs a `libexec/SERVICE_WRAPPER` marker instead. `hermes-dashboard` still uses the old `INSTALL_RECEIPT.json` pattern and would hit the same failure if test-bot installs it; it also fails `brew audit` on CI because its service command (`~/.hermes/hermes-agent/venv/bin/hermes`) does not exist on the runner.
- **`deepseek-harness-desktop` needs the host pkg-config**: Homebrew's `pkgconf` only searches its own prefix, so the formula sets `ENV["PKG_CONFIG"] = /usr/bin/pkg-config` before the Pake compile. Without it, Tauri cannot see the system WebKitGTK `.pc` files.
- **`deepseek-harness-desktop` must redirect `CARGO_TARGET_DIR`**: Pake otherwise writes Cargo's `target/` into the `pake` keg (which is read-only/immutable from Homebrew's point of view). The formula points it at `buildpath/"pake-target"`.
- **`deepseek-harness-desktop` skips npm install scripts on purpose**: `std_npm_args` passes `--ignore-scripts`, and `node-pty` works because it ships prebuilt `prebuilds/linux-*/pty.node` binaries. Do not add `--build-from-source`/`--foreground-scripts` "fixes"; they pull in a full node-gyp toolchain for no benefit.
- **`deepseek-harness-desktop` is Linux only**: `depends_on :linux` plus the WebKitGTK stack means `brew audit` on macOS is not meaningful, and macOS `test-bot` skips it. Linux `test-bot` also lacks the system WebKitGTK dev packages, so CI covers tap syntax/style rather than a full compile.
- **`deepseek-harness-desktop` uses `post_install_steps`**: Homebrew 7 removed the legacy `post_install` method for new formulae. Use `mkdir_p`/`symlink` with `base: :home` / `source_base: :prefix` instead.
- **`hermes-webui-desktop` only bundles PyYAML**: `resource "pyyaml"` is built from the PyPI sdist into `libexec/.venv`. Adding `cryptography` would require a full Rust/OpenSSL build at install time; password auth covers the gap.
- **`hermes-workspace-desktop` needs `--allow-build` flags**: with pnpm 12 a bare `pnpm install --frozen-lockfile` fails on `ERR_PNPM_IGNORED_BUILDS`. Keep esbuild and `unrs-resolver` allowed and electron denied; `--ignore-scripts` does not silence the error.
- **`hermes-workspace-desktop` bundles the SSR server with esbuild**: the ESM output needs the `--banner:js` `createRequire` shim, otherwise `react-dom` throws `Dynamic require of "util" is not supported`. Re-test `node server.mjs` after upgrading upstream.
- **Desktop ports**: `deepseek-harness-desktop` 64710/64711, `ccr-desktop` 64720, `omnirouter-desktop` 64730, `hermes-webui-desktop` 64740, `herdr-desktop` 64750, `openwebui-desktop` 64760, `hermes-workspace-desktop` 64770 — all above the Linux ephemeral range.
- **`deepseek-harness-desktop` launch failures**: On Wayland with proprietary NVIDIA drivers a blank window usually means DMA-BUF compositing failed; `DSH_DESKTOP_DISABLE_DMABUF=1` sets `WEBKIT_DISABLE_DMABUF_RENDERER=1`. A window that does not authenticate means the sidecar port `64711` is occupied by something else.
- **`kilo-desktop` is a deb repack, not a Pake build**: `ar`/`xz` are build dependencies, and the launcher always passes `--no-sandbox` because the deb's `chrome-sandbox` is not setuid. Do not add a Pake/Rust build step or a bottle here; the installed keg is ~1.5 GB.
- **`kilo-desktop` must not carry a `version` line**: Homebrew detects `1.0.0` from `kilo-desktop_1.0.0_amd64.deb`, and `brew audit` rejects an explicit version as redundant. The autobump workflow therefore omits `--version` so `bump-formula-pr` does not insert one.
- **`kilo-desktop --version` launches the app**: it is not a headless version probe, so the formula test checks the installed files instead.

## CI/CD

- **test-*.yml (test-bot)**: `test-oh-my-*.yml`, `test-ccr-service.yml`, `test-hermes-dashboard.yml` and `test-aoe-dashboard.yml` run `brew test-bot` on `macos-26` and `ubuntu-latest` (inside the Homebrew container) to cover tap syntax and formula installation. There is no longer a single `tests.yml`; the bottle-building desktop formulae use their own workflows instead.
- **test-*-desktop.yml**: One workflow per desktop formula, driven by the composite action in `.github/actions/bottle-build/action.yml`. It installs the host build deps, runs `brew install --build-bottle`, `brew test` (early validation), builds the bottle, then uses Homebrew's `brew pr-upload` to publish OCI bottle layers and manifests to GitHub Container Registry at `ghcr.io/v2/coetzeestroom/octavo`. These workflows need `packages: write` as well as `contents: write`; `skopeo` is installed for the registry upload. The bottle gate opens on a push to `main` and on a manual `workflow_dispatch` with `upload: true` (the default); pull requests build only, and a run from any ref other than `refs/heads/main` refuses to push the bottle commit. `pr-upload` updates the bottle block before the existing guarded commit-and-retry step pushes it. Runs on `ubuntu-24.04` (no container), because `actions/checkout` cannot write to the Homebrew container's `/__w` temp dir.
- **autobump.yml**: Scheduled daily at 14:10 UTC. Runs `brew bump --no-fork --open-pr` to auto-update formulae. Only triggers on PR merge to `main` or schedule.
- **bump-deepseek-harness-desktop.yml**: Scheduled daily at 15:10 UTC (plus `workflow_dispatch` and pushes touching its own file). Reads the npm `latest` tag for `@deepseek-ai/dsh`, compares it with the version pinned in the formula, then runs `brew bump-formula-pr --write-only --url=... --version=... --no-audit` on branch `bump-deepseek-harness-desktop-<version>` and opens the PR with `gh`. It skips when a PR for that branch already exists.
- **test-kilo-desktop.yml**: Runs `brew style`, `brew audit --new`, `brew livecheck`, `brew install --build-from-source` and `brew test` on `ubuntu-24.04` for `Formula/kilo-desktop.rb`. There is no bottle step: the formula only repackages the upstream `.deb`.
- **bump-kilo-desktop.yml**: Scheduled daily at 16:50 UTC (plus `workflow_dispatch` and pushes touching its own file). Reads `releases/latest` for `Kilo-Org/kilo-desktop` (GitHub excludes prereleases), selects the `kilo-desktop_*_amd64.deb` asset, and runs `brew bump-formula-pr --write-only --url=... --no-audit` on branch `bump-kilo-desktop-<version>` before opening the PR with `gh`. It deliberately omits `--version` so no redundant version stanza is added.
- **dependabot.yml**: Weekly updates for GitHub Actions. Pinned to `@v6.1.0` for cache, `@v7.0.1` for upload-artifact.
- **publish.yml**: Removed (kept in `.github/removed/` for reference). Not active.

## Shell config

CI workflows use `bash -xeuo pipefail {0}` shell. All formulae use `shell_output(...)` for test commands, typically with `2>/dev/null` to suppress framework chatter.
