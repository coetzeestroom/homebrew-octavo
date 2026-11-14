class OpenwebuiDesktop < Formula
  desc "Desktop app for Open WebUI"
  homepage "https://github.com/open-webui/open-webui"
  url "https://files.pythonhosted.org/packages/8b/a3/aafaaf7d3e353a30ff95db8bccd34b3236dbd4c17049846eb30eb79c0c9e/open_webui-0.13.3.tar.gz"
  version "0.13.3"
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
  APP_NAME = "Open WebUI".freeze

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
    odie "Rust toolchain not found." if which("cargo").nil? || which("rustc").nil?
  end

  def install
    ENV["PKG_CONFIG"] = system_pkg_config
    ENV["PKG_CONFIG_LIBDIR"] = "/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
    ENV["PKG_CONFIG_PATH"] = ""
    check_system_dependencies!

    ENV["CARGO_TARGET_DIR"] = (buildpath/"pake-target").to_s
    ENV.prepend_path "PATH", which("cargo").dirname.to_s
    ENV["CARGO_HOME"] = "#{REAL_HOME}/.cargo"
    ENV["RUSTUP_HOME"] = "#{REAL_HOME}/.rustup"
    ENV.prepend_path "PATH", "#{REAL_HOME}/.cargo/bin"

    # Create an isolated virtualenv and install Open WebUI into it.
    venv = libexec/"venv"
    system "python3", "-m", "venv", venv
    system venv/"bin/pip", "install", "--upgrade", "pip"
    system venv/"bin/pip", "install", "open-webui==#{version}"

    system "pake", "http://127.0.0.1:#{WEB_PORT}/",
           "--name", "OpenWebUI",
           "--identifier", "com.openwebui.desktop",
           "--width", "1280", "--height", "800",
           "--multi-window", "--no-restore-last-url", "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "openwebui-desktop-app"

    owui_bin = "#{opt_libexec}/venv/bin/open-webui"

    (bin/"openwebui-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/openwebui-desktop-app"
      OWUI_BIN="#{owui_bin}"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/openwebui-desktop-${UID}.lock"
      if ! flock -n 9; then echo "Open WebUI Desktop is already running." >&2; exit 1; fi

      "${OWUI_BIN}" serve --port #{WEB_PORT} >/tmp/openwebui-desktop.log 2>&1 &
      owui_pid=$!
      for _ in $(seq 1 100); do
        if (exec 3<>/dev/tcp/127.0.0.1/#{WEB_PORT}) 2>/dev/null; then break; fi
        sleep 0.2
      done

      "${APP_BIN}" "$@" &
      app_pid=$!
      wait "${app_pid}"
      kill "${owui_pid}" 2>/dev/null || true
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
      Start the desktop app (starts Open WebUI on port #{WEB_PORT}):

        openwebui-desktop
    EOS
  end

  test do
    assert_predicate libexec/"openwebui-desktop-app", :executable?
    assert_predicate bin/"openwebui-desktop", :executable?
  end
end
