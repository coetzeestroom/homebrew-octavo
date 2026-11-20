class HermesWorkspaceDesktop < Formula
  desc "Desktop window for the Hermes Workspace"
  homepage "https://github.com/outsourc-e/hermes-workspace"
  url "https://github.com/outsourc-e/hermes-workspace/archive/refs/tags/v2.3.0.tar.gz"
  sha256 "1b0f4478527af098b0cefe33c61ec7dee16e520a30ec195fa0919eba577ddbbc"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "pake" => :build
  depends_on "pnpm" => :build
  depends_on "rust" => :build
  depends_on :linux
  depends_on "node"

  RUST_MIN_VERSION = "1.77".freeze
  REAL_HOME = Dir.home.freeze
  WEB_PORT = 64770
  APP_NAME = "Hermes Workspace".freeze

  # The SSR server is bundled with esbuild so the installed app does not ship
  # ~1 GB of node_modules; CJS dependencies still call `require` for Node
  # builtins, which ESM output needs a real `require` for.
  ESBUILD_BANNER = "import { createRequire as __cr } from 'node:module'; " \
                   "const require = __cr(import.meta.url);".freeze

  def system_pkg_config
    @system_pkg_config ||= %w[/usr/bin/pkg-config /bin/pkg-config].find { |p| File.executable?(p) }
  end

  def os_release_ids
    return [] unless File.exist?("/etc/os-release")

    File.read("/etc/os-release").scan(/^(?:ID|ID_LIKE)=["']?([^"'\n]+)["']?$/).flatten.flat_map(&:split)
  end

  def check_system_dependencies!
    odie "pkg-config not found." if system_pkg_config.nil?
    missing = %w[gtk+-3.0 javascriptcoregtk-4.1 libsoup-3.0 librsvg-2.0 openssl webkit2gtk-4.1].reject do |m|
      quiet_system(system_pkg_config, "--exists", m)
    end
    odie "Missing pkg-config modules: #{missing.join(", ")}" unless missing.empty?
    if which("cargo").nil? || which("rustc").nil?
      odie "Rust toolchain not found (Pake needs Rust #{RUST_MIN_VERSION} or newer)."
    end
  end

  def install
    # Pake links against the host's WebKitGTK/GTK stack, so the system libraries
    # are checked here instead of being declared as (unbottlable) dependencies.
    ENV["PKG_CONFIG"] = system_pkg_config
    ENV["PKG_CONFIG_LIBDIR"] = "/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
    ENV["PKG_CONFIG_PATH"] = ""

    # Pake otherwise writes Cargo's target directory into the read-only pake keg.
    # Rust usually comes from a system or rustup toolchain that Homebrew's build
    # PATH does not include, and Homebrew rewrites HOME during the build.
    ENV["CARGO_TARGET_DIR"] = (buildpath/"pake-target").to_s
    ENV["CARGO_HOME"] = "#{buildpath}/.cargo"
    ENV["RUSTUP_HOME"] = "#{REAL_HOME}/.rustup"
    ENV.prepend_path "PATH", "#{REAL_HOME}/.cargo/bin"

    check_system_dependencies!
    ENV.prepend_path "PATH", which("cargo").dirname.to_s

    # The lockfile pins build scripts for esbuild and the native resolver, and
    # pnpm refuses to install until every scripted dependency is classified.
    # Electron is a desktop-packaging dev dependency and is not needed here.
    system "pnpm", "install", "--frozen-lockfile",
           "--store-dir", (buildpath/".pnpm-store").to_s,
           "--allow-build=esbuild", "--allow-build=unrs-resolver",
           "--allow-build=!electron", "--allow-build=!electron-winstaller"

    ENV["NODE_OPTIONS"] = "--max-old-space-size=4096"
    system "pnpm", "build"

    # Roll the SSR server and its runtime dependencies into one ESM file.
    libexec.mkpath
    system "pnpm", "exec", "esbuild", "server-entry.js",
           "--bundle", "--platform=node", "--format=esm", "--target=node20",
           "--log-level=error", "--banner:js=#{ESBUILD_BANNER}",
           "--outfile=#{libexec}/server.mjs"

    libexec.install "dist", "skills"

    # Compile the Tauri/WebKitGTK window around the loopback SSR server.
    system "pake", "http://127.0.0.1:#{WEB_PORT}/",
           "--name", APP_NAME,
           "--identifier", "ai.hermes.workspace",
           "--width", "1440", "--height", "900",
           "--multi-window", "--no-restore-last-url", "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "hermes-workspace-app"

    (bin/"hermes-workspace-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail

      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/hermes-workspace-app"
      LIBEXEC="#{opt_libexec}"
      PORT="#{WEB_PORT}"
      LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}"
      LOG="${LOG_DIR}/hermes-workspace-desktop.log"
      mkdir -p "${LOG_DIR}"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/hermes-workspace-desktop-${UID}.lock"
      if ! flock -n 9; then
        echo "Hermes Workspace Desktop is already running." >&2
        exit 1
      fi

      cd "${LIBEXEC}"
      HOST=127.0.0.1 \\
      PORT="${PORT}" \\
      NODE_ENV=production \\
        node "${LIBEXEC}/server.mjs" >"${LOG}" 2>&1 &
      server_pid=$!

      cleanup() {
        kill "${server_pid}" 2>/dev/null || true
        wait "${server_pid}" 2>/dev/null || true
      }
      trap cleanup EXIT
      trap 'exit 1' INT TERM HUP

      ready=0
      for _ in $(seq 1 150); do
        if (exec 3<>/dev/tcp/127.0.0.1/"${PORT}") 2>/dev/null; then
          ready=1
          break
        fi
        if ! kill -0 "${server_pid}" 2>/dev/null; then
          break
        fi
        sleep 0.2
      done

      if [[ "${ready}" != "1" ]]; then
        echo "Hermes Workspace did not start on 127.0.0.1:${PORT}." >&2
        echo "See ${LOG} for details." >&2
        exit 1
      fi

      "${APP_BIN}" "$@" &
      app_pid=$!
      set +e
      wait "${app_pid}"
      exit $?
    SH
    chmod 0755, bin/"hermes-workspace-desktop"

    (share/"applications").mkpath
    (share/"applications/hermes-workspace-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=Hermes Workspace
      Comment=Hermes Workspace in an isolated desktop window
      Exec=#{opt_bin}/hermes-workspace-desktop %U
      Terminal=false
      Categories=Development;Network;
      StartupWMClass=hermes-workspace
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/hermes-workspace-desktop.desktop",
            ".local/share/applications/hermes-workspace-desktop.desktop",
            source_base: :prefix,
            target_base: :home,
            overwrite:   true
  end

  def caveats
    <<~EOS
      Start the desktop app (it runs the Workspace server on 127.0.0.1:#{WEB_PORT}
      and stops it again when the window closes):

        hermes-workspace-desktop

      The Workspace is a control plane for a Hermes Agent gateway. Point it at
      your gateway before starting, e.g.:

        export HERMES_API_URL=http://127.0.0.1:8642
        export HERMES_DASHBOARD_URL=http://127.0.0.1:9119

      Without a gateway the window still opens and reports the agent as offline.

      The GTK/WebKitGTK development packages used to compile the window are also
      needed at run time. On Wayland with proprietary NVIDIA drivers, a blank
      window usually means DMA-BUF compositing failed:

        WEBKIT_DISABLE_DMABUF_RENDERER=1 hermes-workspace-desktop

      The desktop menu entry is linked into ~/.local/share/applications; remove
      it by hand after `brew uninstall`:

        rm -f ~/.local/share/applications/hermes-workspace-desktop.desktop
    EOS
  end

  test do
    require "net/http"
    require "socket"

    assert_predicate bin/"hermes-workspace-desktop", :executable?
    assert_predicate libexec/"hermes-workspace-app", :executable?
    assert_predicate libexec/"server.mjs", :file?
    assert_path_exists libexec/"dist/server/server.js"
    assert_path_exists share/"applications/hermes-workspace-desktop.desktop"

    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    env = { "HOST" => "127.0.0.1", "PORT" => port.to_s, "NODE_ENV" => "production" }
    node = formula_opt_bin("node")/"node"
    io = IO.popen(env, [node, libexec/"server.mjs"], chdir: libexec, err: File::NULL)
    begin
      response = nil
      60.times do
        response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
        break
      rescue SystemCallError
        sleep 0.5
      end
      assert_equal "200", response.code
    ensure
      Process.kill("TERM", io.pid)
      Process.wait(io.pid)
    end
  end
end
