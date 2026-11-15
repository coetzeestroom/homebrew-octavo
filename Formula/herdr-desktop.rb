class HerdrDesktop < Formula
  desc "Desktop app for the Herdr web UI"
  homepage "https://github.com/alecuba16/herdr-webui"
  url "https://github.com/alecuba16/herdr-webui/releases/download/v0.7.52/herdr-webui-linux-x86_64.tar.gz"
  sha256 "bcbc5ac1823dfc3d0377deee9a8b7c9d3f61932a42311b14584b7805afc6dafd"
  license "MIT"

  livecheck do
    url "https://github.com/alecuba16/herdr-webui/releases/latest"
    strategy :github_latest
  end

  depends_on "pake" => :build
  depends_on "rust" => :build
  depends_on :linux
  depends_on "node"

  RUST_MIN_VERSION = "1.77".freeze
  REAL_HOME = Dir.home.freeze
  WEB_PORT = 64750
  APP_NAME = "Herdr".freeze

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

    bin.install "herdr-webui"
    bin.install "herdr-webui-tui"

    system "pake", "http://127.0.0.1:#{WEB_PORT}/",
           "--name", APP_NAME,
           "--identifier", "com.herdr.desktop",
           "--width", "1280", "--height", "800",
           "--multi-window", "--no-restore-last-url", "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "herdr-desktop-app"

    (bin/"herdr-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/herdr-desktop-app"
      HERDR_BIN="#{opt_bin}/herdr-webui"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/herdr-desktop-${UID}.lock"
      if ! flock -n 9; then echo "Herdr Desktop is already running." >&2; exit 1; fi

      "${HERDR_BIN}" --https off --backend-mode builtin --bind 127.0.0.1:#{WEB_PORT} >/tmp/herdr-desktop.log 2>&1 &
      herdr_pid=$!
      for _ in $(seq 1 100); do
        if (exec 3<>/dev/tcp/127.0.0.1/#{WEB_PORT}) 2>/dev/null; then break; fi
        sleep 0.2
      done

      "${APP_BIN}" "$@" &
      app_pid=$!
      wait "${app_pid}"
      kill "${herdr_pid}" 2>/dev/null || true
    SH
    chmod 0755, bin/"herdr-desktop"

    (share/"applications").mkpath
    (share/"applications/herdr-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=Herdr
      Comment=Herdr web UI in an isolated desktop window
      Exec=#{opt_bin}/herdr-desktop %U
      Terminal=false
      Categories=Development;Network;
      StartupWMClass=herdr
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/herdr-desktop.desktop",
            ".local/share/applications/herdr-desktop.desktop",
            source_base: :prefix, target_base: :home, overwrite: true
  end

  def caveats
    <<~EOS
      Start the desktop app (starts herdr-webui on port #{WEB_PORT}):

        herdr-desktop
    EOS
  end

  test do
    assert_predicate bin/"herdr-webui", :executable?
    assert_predicate libexec/"herdr-desktop-app", :executable?
    assert_predicate bin/"herdr-desktop", :executable?
  end
end
