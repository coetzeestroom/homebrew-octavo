# Design Document: Cross-Distro Isolated Web App Packaging via Pake and Homebrew

## 1. Overview & Architecture

Declarative, cross-distribution architecture for packaging a web application into an isolated, lightweight native Linux executable (~5–10 MB) managed via Homebrew. Instead of Electron or FUSE-dependent AppImages, this pipeline uses Pake (Tauri + WebKitGTK) compiled locally inside a custom Homebrew Formula.

Key pillars:
- **Session isolation**: Tauri/WebKitGTK stores cookies/localStorage/IndexedDB in an app-scoped XDG directory (`~/.local/share/<bundle-id>`), isolated from the primary browser.
- **Cross-distro portability**: Pake emits a raw, unbundled ELF (`--no-bundle`) — no dpkg-deb/rpm2cpio, identical execution on Arch/Debian/Fedora.
- **Process lifecycle hygiene**: a POSIX wrapper tracks the window PID and traps EXIT/INT/TERM/HUP so closing the window terminates orphaned WebKitWebProcess/WebKitNetworkProcess children.
- **Shared lifecycle for server-backed apps**: when wrapping a local web server (e.g. `dsh web`), start the server, an auth-redirect sidecar, and the window as one unit, killing all three on exit.

## 2. Host System Prerequisites (not Homebrew deps)

Tauri links dynamically against the host's GTK/WebKitGTK. Homebrew's `rust` keg also drags in LLVM (~2 GB), so Rust is treated as a system prerequisite too. Declare these as `depends_on :linux`, `depends_on "node"`, `depends_on "pake" => :build` only — **do not** `depends_on "rust"`. Instead, preflight-check them in `install` and `odie` with distro-specific commands.

Required pkg-config modules: `gtk+-3.0`, `javascriptcoregtk-4.1`, `libsoup-3.0`, `librsvg-2.0`, `openssl`, `webkit2gtk-4.1`.

Arch / CachyOS / EndeavourOS / Manjaro:
```
sudo pacman -S --needed base-devel webkit2gtk-4.1 gtk3 librsvg libayatana-appindicator openssl xdotool rust curl wget file
```
Debian / Ubuntu / Mint / Pop!_OS:
```
sudo apt update && sudo apt install -y build-essential pkg-config libwebkit2gtk-4.1-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev libxdo-dev rustc cargo curl wget file
```
Fedora / RHEL / Rocky / Alma:
```
sudo dnf install -y webkit2gtk4.1-devel openssl-devel libappindicator-gtk3-devel librsvg2-devel libxdo-devel gcc gcc-c++ make pkgconf-pkg-config rust cargo curl wget file
```
openSUSE:
```
sudo zypper install -y webkit2gtk4.1-devel libopenssl-devel libayatana-appindicator3-devel librsvg-devel libxdo-devel gcc gcc-c++ make pkg-config rust cargo curl wget file
```

Notes:
- `libappindicator-gtk3` does not exist on CachyOS; use `libayatana-appindicator`.
- These libraries are needed at run time too — do not remove them after the build.
- A rustup toolchain works too (`install` prepends `dirname(cargo)` to the build `PATH`), but the version check (>= 1.77) still runs.

## 3. Formula skeleton

```ruby
class MyWebapp < Formula
  desc "Isolated Pake desktop wrapper for MyWebApp"
  homepage "https://your-webapp-url.com"
  url "https://registry.npmjs.org/@scope/pkg/-/pkg-1.2.3.tgz" # or a GitHub archive
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on "pake" => :build
  depends_on :linux
  depends_on "node"

  # Ports sit above the Linux ephemeral range (32768-60999).
  WEB_PORT        = 64_710
  REDIRECT_PORT   = 64_711

  # Captured at formula load time, before Homebrew's build superenv rewrites HOME.
  REAL_HOME = Dir.home.freeze

  REQUIRED_PKG_CONFIG_MODULES = %w[
    gtk+-3.0 javascriptcoregtk-4.1 libsoup-3.0 librsvg-2.0 openssl webkit2gtk-4.1
  ].freeze
  RUST_MIN_VERSION = "1.77".freeze

  def os_release_ids
    return [] unless File.exist?("/etc/os-release")

    File.read("/etc/os-release")
        .scan(/^(?:ID|ID_LIKE)=["']?([^"'\n]+)["']?$/)
        .flatten.flat_map(&:split)
  end

  def system_pkg_config
    @system_pkg_config ||= %w[/usr/bin/pkg-config /usr/bin/pkgconf /bin/pkg-config].find do |p|
      File.executable?(p)
    end
  end

  def system_packages_help
    ids = os_release_ids
    if ids.intersect?(%w[arch archarm cachyos endeavouros garuda manjaro])
      "sudo pacman -S --needed base-devel webkit2gtk-4.1 gtk3 librsvg " \
        "libayatana-appindicator openssl xdotool curl wget file"
    elsif ids.intersect?(%w[debian ubuntu linuxmint pop raspbian])
      "sudo apt update && sudo apt install -y build-essential pkg-config " \
        "libwebkit2gtk-4.1-dev libssl-dev libayatana-appindicator3-dev " \
        "librsvg2-dev libxdo-dev curl wget file"
    elsif ids.intersect?(%w[fedora rhel centos rocky almalinux])
      "sudo dnf install -y webkit2gtk4.1-devel openssl-devel " \
        "libappindicator-gtk3-devel librsvg2-devel libxdo-devel gcc gcc-c++ " \
        "make pkgconf-pkg-config curl wget file"
    elsif ids.intersect?(%w[opensuse opensuse-tumbleweed sles])
      "sudo zypper install -y webkit2gtk4.1-devel libopenssl-devel " \
        "libayatana-appindicator3-devel librsvg-devel libxdo-devel gcc " \
        "gcc-c++ make pkg-config curl wget file"
    else
      "Install the WebKitGTK 4.1, GTK 3, librsvg, AppIndicator, " \
        "OpenSSL, xdotool and pkg-config dev packages for your distro."
    end
  end

  def check_system_dependencies!
    problems = []
    if system_pkg_config.nil?
      problems << "pkg-config not found.\n  #{system_packages_help}"
    else
      missing = REQUIRED_PKG_CONFIG_MODULES.reject { |m| quiet_system(system_pkg_config, "--exists", m) }
      problems << "Missing pkg-config modules: #{missing.join(", ")}\n  #{system_packages_help}" unless missing.empty?
    end
    if which("cargo").nil? || which("rustc").nil?
      ids = os_release_ids
      rust_help = if ids.intersect?(%w[arch archarm cachyos endeavouros garuda manjaro])
        "sudo pacman -S --needed rust"
      elsif ids.intersect?(%w[debian ubuntu linuxmint pop raspbian])
        "sudo apt update && sudo apt install -y rustc cargo"
      elsif ids.intersect?(%w[fedora rhel centos rocky almalinux])
        "sudo dnf install -y rust cargo"
      elsif ids.intersect?(%w[opensuse opensuse-tumbleweed sles])
        "sudo zypper install -y rust cargo"
      else
        "Install Rust #{RUST_MIN_VERSION}+ via https://rustup.rs"
      end
      problems << "Rust toolchain (cargo/rustc) not found on PATH.\n  #{rust_help}"
    end
    return if problems.empty?

    odie <<~EOS
      MyWebApp compiles a native WebKitGTK window and needs build tools Homebrew does not provide on Linux.

      #{problems.join("\n\n")}
      These libraries are also needed at run time.
    EOS
  end

  def install
    # Homebrew's build superenv replaces the pkg-config search path with its own
    # prefix. Restore the host search path BEFORE the preflight and the compile.
    ENV["PKG_CONFIG"] = system_pkg_config
    ENV["PKG_CONFIG_LIBDIR"] = "/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
    ENV["PKG_CONFIG_PATH"] = ""

    check_system_dependencies!

    # Pake otherwise writes Cargo's target/ into the pake keg.
    ENV["CARGO_TARGET_DIR"] = (buildpath/"pake-target").to_s
    # Rust comes from the system (often rustup), which the build PATH omits.
    ENV.prepend_path "PATH", which("cargo").dirname.to_s
    # Homebrew rewrites HOME during the build, so pake's rustup lookup (which
    # keys off ~/.cargo/bin and CARGO_HOME) would miss the toolchain otherwise.
    ENV["CARGO_HOME"]    = "#{buildpath}/.cargo"
    ENV["RUSTUP_HOME"]   = "#{REAL_HOME}/.rustup"
    ENV.prepend_path "PATH", "#{REAL_HOME}/.cargo/bin"

    # --- Install the app's source/CLI (adjust per app) ---
    # system "npm", "install", *std_npm_args
    # bin.install_symlink libexec/"bin/my-cli"

    # --- Icon (example: from an npm tree) ---
    # icon = Pathname.glob(libexec/"lib/node_modules/**/dist/icon-512.png").first
    # odie "Could not find icon" if icon.nil?
    # (share/"icons/hicolor/512x512/apps").install icon => "my-webapp.png"

    # --- Pake compile ---
    system "pake",
           "https://your-webapp-url.com",   # or http://127.0.0.1:PORT/ for a server-backed app
           "--name", "MyWebApp",
           "--identifier", "com.example.mywebapp",
           "--icon", icon,                  # omit if pake should fetch the favicon
           "--width", "1280",
           "--height", "800",
           "--multi-window",
           "--no-restore-last-url",
           "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "my-webapp-app"

    # --- (Optional) auth-redirect sidecar for server-backed apps ---
    # (libexec/"auth-redirect.mjs").write <<~JS
    #   import { createServer } from "node:http";
    #   const [target, port] = process.argv.slice(2);
    #   const server = createServer((_req, res) => {
    #     res.writeHead(302, { location: target, "cache-control": "no-store" });
    #     res.end();
    #   });
    #   server.listen(Number(port), "127.0.0.1");
    # JS

    # --- Wrapper script ---
    (bin/"my-webapp").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail

      # GUI launchers start with a minimal PATH.
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/my-webapp-app"
      # AUTH_REDIRECT="#{opt_libexec}/auth-redirect.mjs"   # if using the sidecar

      # Optional Wayland/NVIDIA safeguard:
      # if [[ "${MYWEBAPP_DISABLE_DMABUF:-0}" == "1" ]]; then export WEBKIT_DISABLE_DMABUF_RENDERER=1; fi

      # Single-instance lock:
      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/my-webapp-${UID}.lock"
      if ! flock -n 9; then echo "MyWebApp is already running." >&2; exit 1; fi

      app_pid=""
      cleanup() {
        trap - EXIT INT TERM HUP
        [[ -n "${app_pid}" ]] && kill -TERM "${app_pid}" 2>/dev/null || true
        wait 2>/dev/null || true
        exit "${1:-0}"
      }
      trap 'cleanup $?' EXIT INT TERM HUP

      "${APP_BIN}" "$@" &
      app_pid=$!
      sleep 1
      if ! kill -0 "${app_pid}" 2>/dev/null; then
        echo "MyWebApp failed to start." >&2; exit 1
      fi
      set +e
      wait "${app_pid}"
      exit $?
    SH
    chmod 0755, bin/"my-webapp"

    # --- Desktop entry + icon ---
    (share/"applications").mkpath
    (share/"applications/my-webapp.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=MyWebApp
      Comment=Isolated Pake web app
      Exec=#{opt_bin}/my-webapp %U
      Icon=#{opt_prefix}/share/icons/hicolor/512x512/apps/my-webapp.png
      Terminal=false
      Categories=Network;WebBrowser;
      StartupWMClass=my-webapp
    EOS

    # --- Symlink into the user's menu (Homebrew 7: use post_install_steps) ---
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/my-webapp.desktop",
            ".local/share/applications/my-webapp.desktop",
            source_base: :prefix,
            target_base: :home,
            overwrite:   true
  end

  def caveats
    <<~EOS
      Start with: my-webapp
      Desktop menu entry linked into ~/.local/share/applications; remove by hand
      after uninstall: rm -f ~/.local/share/applications/my-webapp.desktop
    EOS
  end

  test do
    assert_predicate bin/"my-webapp", :executable?
    assert_predicate libexec/"my-webapp-app", :executable?
  end
end
```

## 4. Lessons learned (verified on Arch/CachyOS)

- **Homebrew build superenv rewrites `HOME` and `PATH`.** Capture `REAL_HOME = Dir.home.freeze` at load time; redirect `CARGO_HOME`/`RUSTUP_HOME`/PATH in `install`. Set host pkg-config env *before* the preflight.
- **Homebrew 7 removed `post_install`.** Use `post_install_steps` (`mkdir_p` + `symlink`).
- **`depends_on` ordering is enforced** (build deps, then `:linux`, then runtime deps).
- **`std_npm_args` already passes `--ignore-scripts`.** node-pty ships prebuilds, so it works — don't force install scripts.
- **Pake writes `target/` into the `pake` keg** unless `CARGO_TARGET_DIR` is redirected to buildpath.
- **Homebrew's pkgconf only searches its own prefix** — set `PKG_CONFIG` to the host binary.
- **`Utils.safe_popen_read`** is not reliably available — prefer existence checks.
- **Tap name matters** in workflows (`coetzeestroom`, not `coetzeer`).
- **Auth in server-backed apps can't be disabled** in many tools (e.g. `dsh web` mints a per-process token) — use a loopback redirect sidecar that 302s to the freshly printed authenticated URL; pass `--no-open` to the server.
- **`--multi-window` + `--no-restore-last-url`** keep the window pointed at the sidecar.
- **Auto-merge workflows** run on a PAT and can merge PRs without a human click — gate them on green checks.
- **Nothing uninstalls the user-home symlink automatically** (no uninstall hook) — document `rm -f` in caveats.