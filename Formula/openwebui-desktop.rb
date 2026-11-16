class OpenwebuiDesktop < Formula
  desc "Desktop app for Open WebUI"
  homepage "https://github.com/open-webui/open-webui"
  url "https://files.pythonhosted.org/packages/8b/a3/aafaaf7d3e353a30ff95db8bccd34b3236dbd4c17049846eb30eb79c0c9e/open_webui-0.13.3.tar.gz"
  sha256 "42664cbd2701edf03f3f77a2a1731e880a3ae0dbca2b5cb81607932ba2a5a516"
  license "MIT"

  livecheck do
    url "https://pypi.org/simple/open-webui/"
    regex(/open_webui-(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "pake" => :build
  depends_on "rust" => :build
  depends_on :linux
  depends_on "node"
  depends_on "python@3.12"

  RUST_MIN_VERSION = "1.77".freeze
  REAL_HOME = Dir.home.freeze
  WEB_PORT = 64760
  APP_NAME = "OpenWebUI".freeze
  REQUIRED_PKG_CONFIG_MODULES = %w[
    gtk+-3.0
    javascriptcoregtk-4.1
    libsoup-3.0
    librsvg-2.0
    openssl
    webkit2gtk-4.1
  ].freeze

  # Open WebUI depends on sentence-transformers, which depends on torch. On
  # Linux the default torch wheel hard-depends on the whole NVIDIA CUDA stack
  # (cuda-toolkit, cuDNN, cuBLAS, cuFFT, NCCL, Triton, ... about 2.45 GB of
  # wheels). A desktop window has no use for it, and those multi-hundred-
  # megabyte downloads are what makes the build slow and flaky. Resolving torch
  # from PyTorch's CPU-only index first keeps the CUDA packages out entirely.
  TORCH_CPU_INDEX = "https://download.pytorch.org/whl/cpu".freeze

  def system_pkg_config
    @system_pkg_config ||= %w[/usr/bin/pkg-config /bin/pkg-config].find { |p| File.executable?(p) }
  end

  def os_release_ids
    return [] unless File.exist?("/etc/os-release")

    File.read("/etc/os-release").scan(/^(?:ID|ID_LIKE)=["']?([^"'\n]+)["']?$/).flatten.flat_map(&:split)
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

  def rust_toolchain_help
    ids = os_release_ids
    if ids.intersect?(%w[arch archarm cachyos endeavouros garuda manjaro])
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

    if which("cargo").nil? || which("rustc").nil?
      problems << <<~EOS
        The Rust toolchain (cargo and rustc) was not found on PATH. Pake
        compiles a Tauri app, which needs Rust #{RUST_MIN_VERSION} or newer.

          #{rust_toolchain_help}
      EOS
    end

    return if problems.empty?

    odie <<~EOS
      Open WebUI Desktop compiles a native WebKitGTK window and needs build
      tools that Homebrew does not provide on Linux.

      #{problems.join("\n")}
      These libraries are also needed at run time, so do not remove them after
      the build.
    EOS
  end

  def install
    ENV["PKG_CONFIG"] = system_pkg_config
    ENV["PKG_CONFIG_LIBDIR"] = "/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
    ENV["PKG_CONFIG_PATH"] = ""

    # Pake otherwise writes Cargo's target directory into the read-only pake keg,
    # and Cargo also needs a writable registry cache. Pointing CARGO_HOME at
    # ~/.cargo fails on CI: the runner's .cargo belongs to root, so Cargo cannot
    # create registry/cache there ("failed to create directory
    # /home/runner/.cargo/registry/cache/...: Permission denied"). The build
    # directory is always writable, so Cargo's state lives there instead.
    ENV["CARGO_TARGET_DIR"] = (buildpath/"pake-target").to_s
    ENV["CARGO_HOME"] = "#{buildpath}/.cargo"
    # Homebrew rewrites HOME during the build, so pake's rustup lookup (which
    # keys off ~/.cargo/bin) would otherwise miss the user's toolchain.
    ENV["RUSTUP_HOME"] = "#{REAL_HOME}/.rustup"
    ENV.prepend_path "PATH", "#{REAL_HOME}/.cargo/bin"

    # The preflight runs after the PATH prepends so that a rustup-installed
    # toolchain is found rather than reported as missing.
    check_system_dependencies!
    ENV.prepend_path "PATH", which("cargo").dirname.to_s

    # Create an isolated virtualenv and install Open WebUI into it.
    # Open WebUI 0.13.x requires Python >=3.11,<3.13, so pin python@3.12.
    venv = libexec/"venv"
    system "#{formula_opt_bin("python@3.12")}/python3.12", "-m", "venv", venv
    system venv/"bin/pip", "install", "--upgrade", "pip"

    # Resolve torch before Open WebUI so the CPU-only wheel wins and the CUDA
    # packages are never considered. The index is used exclusively here because
    # it also mirrors torch's own dependencies.
    system venv/"bin/pip", "install",
           "--index-url", TORCH_CPU_INDEX,
           "torch"

    # ~230 packages, so retry harder than pip's defaults: the CUDA wheels are
    # gone, but a slow mirror can still interrupt a large download.
    system venv/"bin/pip", "install",
           "--retries", "10", "--timeout", "120",
           "open-webui==#{version}"

    # Fail the build rather than ship a multi-gigabyte CUDA stack.
    site_packages = Pathname.glob(venv/"lib/python*/site-packages").first
    odie "Could not locate the virtualenv's site-packages directory." if site_packages.nil?
    cuda_packages = %w[nvidia triton].select { |package| (site_packages/package).exist? }
    unless cuda_packages.empty?
      odie "The CUDA torch stack was installed (#{cuda_packages.join(", ")}). " \
           "Check that torch still resolves from #{TORCH_CPU_INDEX}."
    end

    system "pake", "http://127.0.0.1:#{WEB_PORT}/",
           "--name", APP_NAME,
           "--identifier", "com.openwebui.desktop",
           "--width", "1280", "--height", "800",
           "--multi-window", "--no-restore-last-url", "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "openwebui-desktop-app"

    (bin/"openwebui-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/openwebui-desktop-app"
      OWUI_BIN="#{opt_libexec}/venv/bin/open-webui"
      PORT="#{WEB_PORT}"

      # Open WebUI writes its SQLite database and uploads into DATA_DIR, which
      # defaults to a directory inside the package (and therefore inside the
      # read-only keg, which `brew upgrade` replaces). Keep the data in the
      # user's home directory instead.
      DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/open-webui"
      LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}"
      LOG="${LOG_DIR}/openwebui-desktop.log"
      mkdir -p "${DATA_DIR}" "${LOG_DIR}"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/openwebui-desktop-${UID}.lock"
      if ! flock -n 9; then
        echo "Open WebUI Desktop is already running." >&2
        exit 1
      fi

      # `open-webui serve` writes its generated secret key to the current
      # directory, so run from the data directory rather than wherever the
      # window happened to be launched from.
      cd "${DATA_DIR}"
      export DATA_DIR

      "${OWUI_BIN}" serve --host 127.0.0.1 --port "${PORT}" >"${LOG}" 2>&1 &
      owui_pid=$!

      cleanup() {
        kill "${owui_pid}" 2>/dev/null || true
        wait "${owui_pid}" 2>/dev/null || true
      }
      trap cleanup EXIT
      trap 'exit 1' INT TERM HUP

      ready=0
      for _ in $(seq 1 600); do
        if (exec 3<>/dev/tcp/127.0.0.1/"${PORT}") 2>/dev/null; then
          ready=1
          break
        fi
        if ! kill -0 "${owui_pid}" 2>/dev/null; then
          break
        fi
        sleep 0.2
      done

      if [[ "${ready}" != "1" ]]; then
        echo "Open WebUI did not start on 127.0.0.1:${PORT}." >&2
        echo "See ${LOG} for details." >&2
        exit 1
      fi

      "${APP_BIN}" "$@" &
      app_pid=$!
      set +e
      wait "${app_pid}"
      exit $?
    SH
    chmod 0755, bin/"openwebui-desktop"

    (share/"applications").mkpath
    (share/"applications/openwebui-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=Open WebUI
      Comment=Open WebUI in an isolated desktop window
      Exec=#{opt_bin}/openwebui-desktop %U
      Terminal=false
      Categories=Network;
      StartupWMClass=openwebui
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/openwebui-desktop.desktop",
            ".local/share/applications/openwebui-desktop.desktop",
            source_base: :prefix, target_base: :home, overwrite: true
  end

  def caveats
    <<~EOS
      Start the desktop app (it runs Open WebUI on 127.0.0.1:#{WEB_PORT} and
      stops it again when the window closes):

        openwebui-desktop

      The first account you sign up with becomes the administrator. Chats,
      uploads and settings live in
      ~/.local/share/open-webui (or $XDG_DATA_HOME/open-webui) and survive
      `brew upgrade`; the log is at
      ~/.local/state/openwebui-desktop.log.

      Model inference runs on the CPU: torch is installed from the CPU-only
      index, so there is no CUDA stack in this build.

      The GTK/WebKitGTK development packages used to compile the window are also
      needed at run time. On Wayland with proprietary NVIDIA drivers, a blank
      window usually means DMA-BUF compositing failed:

        WEBKIT_DISABLE_DMABUF_RENDERER=1 openwebui-desktop

      The desktop menu entry is linked into ~/.local/share/applications; remove
      it by hand after `brew uninstall`:

        rm -f ~/.local/share/applications/openwebui-desktop.desktop
    EOS
  end

  test do
    require "net/http"
    require "socket"

    assert_predicate bin/"openwebui-desktop", :executable?
    assert_predicate libexec/"openwebui-desktop-app", :executable?
    assert_path_exists share/"applications/openwebui-desktop.desktop"

    # The CUDA stack is ~2.45 GB of wheels this window never uses, so fail the
    # build rather than ship it.
    site_packages = Pathname.glob(libexec/"venv/lib/python*/site-packages").first
    %w[nvidia triton].each do |cuda_package|
      refute_path_exists site_packages/cuda_package
    end

    # Boot the real server and wait for /health, so a broken payload fails here
    # rather than the first time a user launches the window.
    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    (testpath/"data").mkpath
    env = {
      "DATA_DIR"         => (testpath/"data").to_s,
      "WEBUI_SECRET_KEY" => "homebrew-formula-test-key",
      "WEBUI_AUTH"       => "false",
      "OFFLINE_MODE"     => "true",
    }
    io = IO.popen(env, [libexec/"venv/bin/open-webui", "serve",
                        "--host", "127.0.0.1", "--port", port.to_s],
                  chdir: testpath/"data", err: File::NULL)
    begin
      response = nil
      240.times do
        response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/health"))
        break if response.code == "200"

        sleep 0.5
      rescue SystemCallError, EOFError
        sleep 0.5
      end
      assert_equal "200", response&.code
    ensure
      Process.kill("TERM", io.pid)
      Process.wait(io.pid)
    end
  end
end
