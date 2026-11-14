class CcrDesktop < Formula
  desc "Desktop app for the Claude Code Router (ccr) web UI"
  homepage "https://github.com/musistudio/claude-code-router"
  url "https://registry.npmjs.org/claude-code-router/-/claude-code-router-2.1.1.tgz"
  version "2.1.1"
  sha256 "0cf80f9e3153cd173d11b705d0c42ac9f4433dd1af94c8d6033bde0d2c984fd4"
  license "MIT"

  livecheck do
    url "https://registry.npmjs.org/claude-code-router/latest"
    strategy :json do |json|
      json["version"]
    end
  end

  depends_on "pake" => :build
  depends_on "rust" => :build
  depends_on "claude-code-router"
  depends_on :linux
  depends_on "node"

  RUST_MIN_VERSION = "1.77".freeze
  REAL_HOME = Dir.home.freeze
  WEB_PORT = 64720
  APP_NAME = "Claude Code Router".freeze

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

    system "pake", "http://127.0.0.1:#{WEB_PORT}/",
           "--name", "CCR",
           "--identifier", "com.ccr.desktop",
           "--width", "1280", "--height", "800",
           "--multi-window", "--no-restore-last-url", "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "ccr-desktop-app"

    ccr_bin = "#{HOMEBREW_PREFIX}/opt/claude-code-router/bin/ccr"

    (bin/"ccr-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/ccr-desktop-app"
      CCR_BIN="#{ccr_bin}"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/ccr-desktop-${UID}.lock"
      if ! flock -n 9; then echo "CCR Desktop is already running." >&2; exit 1; fi

      "${CCR_BIN}" serve --no-open --port #{WEB_PORT} >/tmp/ccr-desktop.log 2>&1 &
      ccr_pid=$!
      for _ in $(seq 1 100); do
        if (exec 3<>/dev/tcp/127.0.0.1/#{WEB_PORT}) 2>/dev/null; then break; fi
        sleep 0.2
      done

      "${APP_BIN}" "$@" &
      app_pid=$!
      wait "${app_pid}"
      kill "${ccr_pid}" 2>/dev/null || true
    SH
    chmod 0755, bin/"ccr-desktop"

    (share/"applications").mkpath
    (share/"applications/ccr-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=Claude Code Router
      Comment=Claude Code Router web UI in an isolated desktop window
      Exec=#{opt_bin}/ccr-desktop %U
      Terminal=false
      Categories=Development;Network;
      StartupWMClass=ccr
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/ccr-desktop.desktop",
            ".local/share/applications/ccr-desktop.desktop",
            source_base: :prefix, target_base: :home, overwrite: true
  end

  def caveats
    <<~EOS
      Start the desktop app (starts ccr on port #{WEB_PORT}):

        ccr-desktop
    EOS
  end

  test do
    assert_predicate libexec/"ccr-desktop-app", :executable?
    assert_predicate bin/"ccr-desktop", :executable?
  end
end
