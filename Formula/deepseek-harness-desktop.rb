class DeepseekHarnessDesktop < Formula
  desc "Desktop app for the DeepSeek Harness (dsh) agent web UI"
  homepage "https://github.com/deepseek-ai/deepseek-harness"
  url "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-0.2.2-rc.1.tgz"
  sha256 "ad21968aed0337a326b853507a23b30eacbbec4d67ab07f3b6fde69b75b19cd6"
  license "MIT"

  livecheck do
    url "https://registry.npmjs.org/@deepseek-ai/dsh/latest"
    strategy :json do |json|
      json["version"]
    end
  end

  depends_on "pake" => :build
  depends_on :linux
  depends_on "node"

  # The Pake/Tauri compile needs a full Rust toolchain. Homebrew's `rust`
  # keg pulls in LLVM (well over a gigabyte), so Rust is treated as a system
  # build prerequisite and checked in `install` instead.
  RUST_MIN_VERSION = "1.77".freeze

  # Captured at formula load time (in the invoking user's environment), before
  # Homebrew's build superenv rewrites HOME to a temporary directory.
  REAL_HOME = Dir.home.freeze
  DSH_WEB_PORT = 64_710
  AUTH_REDIRECT_PORT = 64_711

  # Tauri links against the host's WebKitGTK/GTK stack rather than Homebrew's,
  # so these are checked before the (long) Pake compile starts.
  REQUIRED_PKG_CONFIG_MODULES = %w[
    gtk+-3.0
    javascriptcoregtk-4.1
    libsoup-3.0
    librsvg-2.0
    openssl
    webkit2gtk-4.1
  ].freeze

  def system_pkg_config
    @system_pkg_config ||= %w[/usr/bin/pkg-config /usr/bin/pkgconf /bin/pkg-config].find do |path|
      File.executable?(path)
    end
  end

  def os_release_ids
    return [] unless File.exist?("/etc/os-release")

    File.read("/etc/os-release")
        .scan(/^(?:ID|ID_LIKE)=["']?([^"'\n]+)["']?$/)
        .flatten
        .flat_map(&:split)
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
        "libayatana-appindicator3-devel librsvg-devel libxdo-devel gcc gcc-c++ " \
        "make pkg-config curl wget file"
    else
      <<~EOS
        Use your distribution's package manager to install the WebKitGTK 4.1,
        GTK 3, librsvg, AppIndicator, OpenSSL, xdotool and pkg-config
        development packages (for example libwebkit2gtk-4.1-dev on Debian,
        webkit2gtk4.1-devel on Fedora, webkit2gtk-4.1 on Arch).
      EOS
    end
  end

  def check_system_dependencies!
    problems = []

    if system_pkg_config.nil?
      problems << <<~EOS
        pkg-config was not found. It is needed to locate the WebKitGTK and GTK
        development files that Tauri links against.

          #{system_packages_help}
      EOS
    else
      missing = REQUIRED_PKG_CONFIG_MODULES.reject do |mod|
        quiet_system(system_pkg_config, "--exists", mod)
      end
      unless missing.empty?
        problems << <<~EOS
          Missing pkg-config modules: #{missing.join(", ")}

            #{system_packages_help}
        EOS
      end
    end

    rustc = which("rustc")
    if which("cargo").nil? || rustc.nil?
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
        "Install Rust #{RUST_MIN_VERSION} or newer, for example with " \
          "https://rustup.rs (`rustup default stable`)."
      end
      problems << <<~EOS
        The Rust toolchain (cargo and rustc) was not found on PATH. Pake
        compiles a Tauri app, which needs Rust #{RUST_MIN_VERSION} or newer.

          #{rust_help}
      EOS
    end

    return if problems.empty?

    odie <<~EOS
      DeepSeek Harness Desktop compiles a native WebKitGTK window and needs
      build tools that Homebrew does not provide on Linux.

      #{problems.join("\n")}
      These libraries are also needed at run time, so do not remove them after
      the build.
    EOS
  end

  def install
    # Homebrew's build superenv replaces the pkg-config search path with its
    # own prefix, hiding the system WebKitGTK/GTK .pc files. Restore the
    # host search path before the preflight and the Pake compile.
    ENV["PKG_CONFIG"] = system_pkg_config
    ENV["PKG_CONFIG_LIBDIR"] = "/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
    ENV["PKG_CONFIG_PATH"] = ""

    check_system_dependencies!

    # Pake otherwise puts Cargo's target directory inside the `pake` keg.
    ENV["CARGO_TARGET_DIR"] = (buildpath/"pake-target").to_s
    # Rust comes from the system (often rustup), which Homebrew's build PATH
    # does not include.
    ENV.prepend_path "PATH", which("cargo").dirname.to_s
    # Homebrew rewrites HOME during the build, so pake's rustup lookup (which
    # keys off ~/.cargo/bin and CARGO_HOME) would otherwise miss the user's
    # toolchain. Point it at the invoking user's real home.
    ENV["CARGO_HOME"] = "#{buildpath}/.cargo"
    ENV["RUSTUP_HOME"] = "#{REAL_HOME}/.rustup"
    ENV.prepend_path "PATH", "#{REAL_HOME}/.cargo/bin"

    # `dsh` resolves the bundles named in its profile from this tree; the
    # profile itself is created in $DSH_HOME on first launch.
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec/"bin/dsh"

    # Trim non-runtime files from the npm tree to keep the installed payload small:
    # TypeScript declarations, source maps and per-package docs are not needed
    # at run time. LICENSE files are intentionally kept for compliance.
    system "find", (libexec/"lib/node_modules").to_s, "-type", "f",
           "(", "-name", "*.map", "-o", "-name", "*.d.ts",
           "-o", "-name", "README.md", "-o", "-name", "CHANGELOG.md", ")",
           "-delete"

    icon = Pathname.glob(libexec/"lib/node_modules/**/dsh-web-frontend/dist/icon-512.png").first
    odie "Could not find the DeepSeek Harness icon in the installed npm tree" if icon.nil?
    (share/"icons/hicolor/512x512/apps").install icon => "deepseek-harness-desktop.png"

    # Wrap the local web UI in a standalone Tauri/WebKitGTK ELF binary. The URL
    # is the loopback auth-redirect sidecar below, because `dsh web` prints a
    # fresh per-process token on every launch and Pake bakes its URL at compile
    # time. `--no-bundle` keeps the output a raw binary for any distro.
    system "pake",
           "http://127.0.0.1:#{AUTH_REDIRECT_PORT}/",
           "--name", "DeepSeek Harness",
           "--identifier", "com.deepseek.harness.desktop",
           "--icon", icon,
           "--width", "1440",
           "--height", "900",
           "--multi-window",
           "--no-restore-last-url",
           "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "deepseek-harness-app"

    (libexec/"auth-redirect.mjs").write <<~JS
      // Loopback sidecar: `dsh web` mints a random launch token per process and
      // only exchanges it for the browser cookie at `/?token=<token>`. The
      // compiled Pake window cannot know that token, so it loads this server
      // instead and is redirected to the freshly printed authenticated URL.
      import { createServer } from "node:http";

      const [target, port] = process.argv.slice(2);
      if (target === undefined || port === undefined) {
        console.error("usage: auth-redirect.mjs <authenticated-url> <port>");
        process.exit(64);
      }

      const server = createServer((_request, response) => {
        response.writeHead(302, {
          location: target,
          "cache-control": "no-store",
          "referrer-policy": "no-referrer",
        });
        response.end();
      });

      server.on("error", (error) => {
        console.error(`dsh auth redirect: ${error.message}`);
        process.exit(1);
      });

      server.listen(Number(port), "127.0.0.1");
    JS

    (bin/"deepseek-harness-desktop").write <<~SH
      #!/usr/bin/env bash
      # Runs the DeepSeek Harness web server, the loopback auth-redirect sidecar
      # and the Pake window as one unit: closing the window (or interrupting
      # this script) stops all three.
      set -euo pipefail

      # GUI launchers start with a minimal PATH, so put the Homebrew Node (used
      # by the sidecar and by the dsh shebang) on PATH regardless of the
      # user's shell profile.
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      DSH_BIN="${DSH_BIN:-#{opt_bin}/dsh}"
      APP_BIN="#{opt_libexec}/deepseek-harness-app"
      AUTH_REDIRECT="#{opt_libexec}/auth-redirect.mjs"
      DSH_PORT="${DSH_DESKTOP_PORT:-#{DSH_WEB_PORT}}"
      AUTH_PORT="#{AUTH_REDIRECT_PORT}"

      # WebKitGTK renders a blank window on some Wayland + proprietary NVIDIA
      # setups; set DSH_DESKTOP_DISABLE_DMABUF=1 to take the software path.
      if [[ "${DSH_DESKTOP_DISABLE_DMABUF:-0}" == "1" ]]; then
        export WEBKIT_DISABLE_DMABUF_RENDERER=1
      fi

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/deepseek-harness-desktop-${UID}.lock"
      if ! flock -n 9; then
        echo "DeepSeek Harness Desktop is already running." >&2
        exit 1
      fi

      log_file="$(mktemp "${TMPDIR:-/tmp}/deepseek-harness-desktop.XXXXXX")"
      dsh_pid=""
      broker_pid=""
      app_pid=""

      cleanup() {
        local status=$?
        trap - EXIT INT TERM HUP
        if [[ -n "${app_pid}" ]] && kill -0 "${app_pid}" 2>/dev/null; then
          kill -TERM "${app_pid}" 2>/dev/null || true
        fi
        if [[ -n "${broker_pid}" ]] && kill -0 "${broker_pid}" 2>/dev/null; then
          kill -TERM "${broker_pid}" 2>/dev/null || true
        fi
        if [[ -n "${dsh_pid}" ]] && kill -0 "${dsh_pid}" 2>/dev/null; then
          pkill -TERM -P "${dsh_pid}" 2>/dev/null || true
          kill -TERM "${dsh_pid}" 2>/dev/null || true
        fi
        wait 2>/dev/null || true
        rm -f "${log_file}"
        exit "${status}"
      }
      trap cleanup EXIT INT TERM HUP

      "${DSH_BIN}" web --no-open --port "${DSH_PORT}" >"${log_file}" 2>&1 &
      dsh_pid=$!

      # Wait for the launcher to print its authenticated URL.
      auth_url=""
      for _ in $(seq 1 600); do
        while IFS= read -r line || [[ -n "${line}" ]]; do
          if [[ "${line}" =~ (https?://[^[:space:]]*[?&]token=[^[:space:]]+) ]]; then
            auth_url="${BASH_REMATCH[1]}"
            break
          fi
        done <"${log_file}"
        if [[ -n "${auth_url}" ]]; then
          break
        fi
        if ! kill -0 "${dsh_pid}" 2>/dev/null; then
          echo "dsh web exited before printing an authenticated URL:" >&2
          sed 's/^/  /' "${log_file}" >&2
          exit 1
        fi
        sleep 0.2
      done

      if [[ -z "${auth_url}" ]]; then
        echo "Timed out waiting for dsh web on port ${DSH_PORT}:" >&2
        sed 's/^/  /' "${log_file}" >&2
        exit 1
      fi

      node "${AUTH_REDIRECT}" "${auth_url}" "${AUTH_PORT}" &
      broker_pid=$!

      broker_ready=0
      for _ in $(seq 1 100); do
        if (exec 3<>"/dev/tcp/127.0.0.1/${AUTH_PORT}") 2>/dev/null; then
          broker_ready=1
          break
        fi
        if ! kill -0 "${broker_pid}" 2>/dev/null; then
          echo "The dsh auth redirect sidecar failed to start on port ${AUTH_PORT}." >&2
          exit 1
        fi
        sleep 0.1
      done

      if [[ "${broker_ready}" != "1" ]]; then
        echo "Timed out waiting for the dsh auth redirect sidecar on port ${AUTH_PORT}." >&2
        exit 1
      fi

      "${APP_BIN}" "$@" &
      app_pid=$!

      sleep 1
      if ! kill -0 "${app_pid}" 2>/dev/null; then
        echo "The DeepSeek Harness window failed to start." >&2
        echo "Check that the WebKitGTK runtime libraries are still installed." >&2
        exit 1
      fi

      set +e
      wait "${app_pid}"
      exit $?
    SH
    chmod 0755, bin/"deepseek-harness-desktop"

    (share/"applications").mkpath
    (share/"applications/deepseek-harness-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=DeepSeek Harness
      Comment=DeepSeek Harness agent web UI in an isolated desktop window
      Exec=#{opt_bin}/deepseek-harness-desktop %U
      Icon=#{opt_prefix}/share/icons/hicolor/512x512/apps/deepseek-harness-desktop.png
      Terminal=false
      Categories=Development;Network;
      StartupWMClass=deepseek-harness
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/deepseek-harness-desktop.desktop",
            ".local/share/applications/deepseek-harness-desktop.desktop",
            source_base: :prefix,
            target_base: :home,
            overwrite:   true
  end

  def caveats
    <<~EOS
      Start the desktop app (dsh web, the auth redirect sidecar and the window
      all stop together when the window closes):

        deepseek-harness-desktop

      The bundled `dsh` CLI shares the same ~/.dsh harness home, so agents and
      credentials configured in the window are available in a terminal too.

      Ports (both above the Linux ephemeral range):
        dsh web UI          127.0.0.1:#{DSH_WEB_PORT}  override with DSH_DESKTOP_PORT
        auth redirect       127.0.0.1:#{AUTH_REDIRECT_PORT}  baked into the window at build time

      The GTK/WebKitGTK development packages used to compile the window are
      also needed at run time. On Wayland with proprietary NVIDIA drivers, a
      blank window usually means DMA-BUF compositing failed:

        DSH_DESKTOP_DISABLE_DMABUF=1 deepseek-harness-desktop

      The desktop menu entry is linked into ~/.local/share/applications; remove
      it by hand after `brew uninstall`:

        rm -f ~/.local/share/applications/deepseek-harness-desktop.desktop
    EOS
  end

  test do
    require "net/http"
    require "socket"

    assert_predicate bin/"deepseek-harness-desktop", :executable?
    assert_predicate libexec/"deepseek-harness-app", :executable?
    assert_predicate libexec/"auth-redirect.mjs", :file?
    assert_path_exists share/"applications/deepseek-harness-desktop.desktop"
    assert_match version.to_s, shell_output("#{bin}/dsh --version")

    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    target = "http://127.0.0.1:1/?token=test-token"
    io = IO.popen(["node", libexec/"auth-redirect.mjs", target, port.to_s], err: File::NULL)
    begin
      sleep 1
      response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
      assert_equal "302", response.code
      assert_equal target, response["location"]
    ensure
      Process.kill("TERM", io.pid)
      Process.wait(io.pid)
    end
  end
end
