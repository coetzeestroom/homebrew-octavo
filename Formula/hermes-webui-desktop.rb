class HermesWebuiDesktop < Formula
  include Language::Python::Virtualenv

  desc "Desktop window for the Hermes WebUI"
  homepage "https://github.com/nesquena/hermes-webui"
  url "https://github.com/nesquena/hermes-webui/archive/refs/tags/v0.52.678.tar.gz"
  sha256 "eecc3989e4484c2bc7d2bef1586f8b693e3972f7f3fac0d1dafb74510689df12"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "node" => :build
  depends_on "pake" => :build
  depends_on "rust" => :build
  depends_on "libyaml"
  depends_on :linux
  depends_on "python@3.13"

  RUST_MIN_VERSION = "1.77".freeze
  REAL_HOME = Dir.home.freeze
  WEB_PORT = 64740
  APP_NAME = "Hermes WebUI".freeze

  # The WebUI only needs PyYAML at run time. `cryptography` (upstream's optional
  # passkey/WebAuthn support) is deliberately not bundled: it would drag a full
  # Rust build into every install. Password auth via HERMES_WEBUI_PASSWORD works
  # without it.
  resource "pyyaml" do
    url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
    sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  end

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

    # Only the files the server actually loads are installed; docs, tests,
    # container files and Nix expressions are left out of the bottle.
    libexec.install "server.py", "api", "static", "scripts", "bootstrap.py",
                    "managed_agent_startup.py", "mcp_server.py", "pyproject.toml",
                    "requirements.txt", "LICENSE", "README.md"

    # Upstream's config discovery looks for `.venv` inside the repo root, so the
    # Homebrew-managed virtualenv lives at libexec/.venv on purpose.
    venv = virtualenv_create(libexec/".venv", "python3.13")
    venv.pip_install resource("pyyaml")

    # Compile the Tauri/WebKitGTK window around the loopback WebUI.
    system "pake", "http://127.0.0.1:#{WEB_PORT}/",
           "--name", APP_NAME,
           "--identifier", "ai.hermes.webui",
           "--width", "1440", "--height", "900",
           "--multi-window", "--no-restore-last-url", "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "hermes-webui-app"

    (bin/"hermes-webui-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail

      export PATH="#{formula_opt_bin("python@3.13")}:${PATH}"

      APP_BIN="#{opt_libexec}/hermes-webui-app"
      LIBEXEC="#{opt_libexec}"
      PORT="#{WEB_PORT}"
      LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}"
      LOG="${LOG_DIR}/hermes-webui-desktop.log"
      mkdir -p "${LOG_DIR}"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/hermes-webui-desktop-${UID}.lock"
      if ! flock -n 9; then
        echo "Hermes WebUI Desktop is already running." >&2
        exit 1
      fi

      HERMES_WEBUI_HOST=127.0.0.1 \\
      HERMES_WEBUI_PORT="${PORT}" \\
        "${LIBEXEC}/.venv/bin/python" "${LIBEXEC}/server.py" >"${LOG}" 2>&1 &
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
        echo "Hermes WebUI did not start on 127.0.0.1:${PORT}." >&2
        echo "See ${LOG} for details." >&2
        exit 1
      fi

      "${APP_BIN}" "$@" &
      app_pid=$!
      set +e
      wait "${app_pid}"
      exit $?
    SH
    chmod 0755, bin/"hermes-webui-desktop"

    (share/"applications").mkpath
    (share/"applications/hermes-webui-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=Hermes WebUI
      Comment=Hermes WebUI in an isolated desktop window
      Exec=#{opt_bin}/hermes-webui-desktop %U
      Terminal=false
      Categories=Development;Network;
      StartupWMClass=hermes-webui
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/hermes-webui-desktop.desktop",
            ".local/share/applications/hermes-webui-desktop.desktop",
            source_base: :prefix,
            target_base: :home,
            overwrite:   true
  end

  def caveats
    <<~EOS
      Start the desktop app (it runs the WebUI on 127.0.0.1:#{WEB_PORT} and stops
      it again when the window closes):

        hermes-webui-desktop

      Chat needs a running Hermes Agent gateway; the UI itself starts without
      one and reports the agent as offline.

      Authentication: set HERMES_WEBUI_PASSWORD to require a password. Optional
      passkey/WebAuthn support is not bundled (it needs Python `cryptography`);
      the server starts fine without it.

      Logs, PID and session state follow upstream defaults (~/.hermes) unless
      HERMES_WEBUI_STATE_DIR is set.

      The GTK/WebKitGTK development packages used to compile the window are also
      needed at run time. On Wayland with proprietary NVIDIA drivers, a blank
      window usually means DMA-BUF compositing failed:

        WEBKIT_DISABLE_DMABUF_RENDERER=1 hermes-webui-desktop

      The desktop menu entry is linked into ~/.local/share/applications; remove
      it by hand after `brew uninstall`:

        rm -f ~/.local/share/applications/hermes-webui-desktop.desktop
    EOS
  end

  test do
    require "net/http"
    require "socket"

    assert_predicate bin/"hermes-webui-desktop", :executable?
    assert_predicate libexec/"hermes-webui-app", :executable?
    assert_path_exists share/"applications/hermes-webui-desktop.desktop"
    assert_match "6.0", shell_output("#{libexec}/.venv/bin/python -c 'import yaml; print(yaml.__version__)'")

    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    (testpath/"state").mkpath
    env = {
      "HERMES_WEBUI_HOST"      => "127.0.0.1",
      "HERMES_WEBUI_PORT"      => port.to_s,
      "HERMES_WEBUI_STATE_DIR" => (testpath/"state").to_s,
    }
    io = IO.popen(env, [libexec/".venv/bin/python", libexec/"server.py"], chdir: libexec, err: File::NULL)
    begin
      response = nil
      60.times do
        response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/health"))
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
