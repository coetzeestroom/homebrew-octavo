class HermesDesktop < Formula
  desc "Desktop app for the Hermes Agent web UI"
  homepage "https://hermes-agent.nousresearch.com"
  url "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.9.24.tar.gz"
  sha256 "15b15ce4e6ec8ea424a081823709d1e17f0943e7b42b59597d24ebb94cbd1742"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_releases
  end

  depends_on "pake" => :build
  depends_on "rust" => :build
  depends_on "hermes-agent"
  depends_on :linux
  depends_on "node"

  RUST_MIN_VERSION = "1.77".freeze
  REAL_HOME = Dir.home.freeze
  WEB_PORT = 64740
  APP_NAME = "Hermes".freeze

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
           "--name", APP_NAME,
           "--identifier", "com.hermes.desktop",
           "--width", "1280", "--height", "800",
           "--multi-window", "--no-restore-last-url", "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "hermes-desktop-app"

    hermes_bin = "#{Dir.home}/.hermes/hermes-agent/venv/bin/hermes"

    (bin/"hermes-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/hermes-desktop-app"
      HERMES_BIN="#{hermes_bin}"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/hermes-desktop-${UID}.lock"
      if ! flock -n 9; then echo "Hermes Desktop is already running." >&2; exit 1; fi

      "${HERMES_BIN}" dashboard --port #{WEB_PORT} --host 127.0.0.1 --no-open --insecure >/tmp/hermes-desktop.log 2>&1 &
      hermes_pid=$!
      for _ in $(seq 1 100); do
        if (exec 3<>/dev/tcp/127.0.0.1/#{WEB_PORT}) 2>/dev/null; then break; fi
        sleep 0.2
      done

      "${APP_BIN}" "$@" &
      app_pid=$!
      wait "${app_pid}"
      kill "${hermes_pid}" 2>/dev/null || true
    SH
    chmod 0755, bin/"hermes-desktop"

    (share/"applications").mkpath
    (share/"applications/hermes-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=Hermes
      Comment=Hermes Agent web UI in an isolated desktop window
      Exec=#{opt_bin}/hermes-desktop %U
      Terminal=false
      Categories=Development;Network;
      StartupWMClass=hermes
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/hermes-desktop.desktop",
            ".local/share/applications/hermes-desktop.desktop",
            source_base: :prefix, target_base: :home, overwrite: true
  end

  def caveats
    <<~EOS
      Start the desktop app (starts hermes dashboard on port #{WEB_PORT}):

        hermes-desktop
    EOS
  end

  test do
    assert_predicate libexec/"hermes-desktop-app", :executable?
    assert_predicate bin/"hermes-desktop", :executable?
  end
end
