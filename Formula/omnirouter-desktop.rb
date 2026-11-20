class OmnirouterDesktop < Formula
  desc "Desktop app for the OmniRouter web UI"
  homepage "https://github.com/Godde3s/omnirouter"
  url "https://github.com/Godde3s/omnirouter/releases/download/v1.4.0/dist-omnirouter-linux-amd64.tar.gz"
  sha256 "883d2ea6e7a3d9069a4e08f6883814d1db29afb3901d9a7e12bd748349f4b488"
  license "MIT"

  livecheck do
    url "https://github.com/Godde3s/omnirouter/releases/latest"
    strategy :github_latest
  end

  depends_on "pake" => :build
  depends_on "rust" => :build
  depends_on :linux
  depends_on "node"

  RUST_MIN_VERSION = "1.77".freeze
  REAL_HOME = Dir.home.freeze
  WEB_PORT = 64730
  APP_NAME = "OmniRouter".freeze

  def system_pkg_config
    @system_pkg_config ||= %w[/usr/bin/pkg-config /usr/bin/pkg-config /bin/pkg-config].find do |path|
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
    "Install WebKitGTK 4.1, GTK 3, librsvg, OpenSSL, xdotool and pkg-config dev packages."
  end

  def install
    ENV["PKG_CONFIG"] = system_pkg_config
    ENV["PKG_CONFIG_LIBDIR"] = "/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
    ENV["PKG_CONFIG_PATH"] = ""
    if system_pkg_config.nil?
      odie "pkg-config not found. #{system_packages_help}"
    end
    missing = %w[gtk+-3.0 javascriptcoregtk-4.1 libsoup-3.0 librsvg-2.0 openssl webkit2gtk-4.1].reject do |mod|
      quiet_system(system_pkg_config, "--exists", mod)
    end
    unless missing.empty?
      odie "Missing pkg-config modules: #{missing.join(", ")}. #{system_packages_help}"
    end
    if which("cargo").nil? || which("rustc").nil?
      odie "Rust toolchain not found. Install Rust #{RUST_MIN_VERSION}+."
    end

    ENV["CARGO_TARGET_DIR"] = (buildpath/"pake-target").to_s
    ENV.prepend_path "PATH", which("cargo").dirname.to_s
    ENV["CARGO_HOME"] = "#{REAL_HOME}/.cargo"
    ENV["RUSTUP_HOME"] = "#{REAL_HOME}/.rustup"
    ENV.prepend_path "PATH", "#{REAL_HOME}/.cargo/bin"

    # Install the upstream Go binary.
    bin.install "omnirouter-linux-amd64" => "omnirouter"

    # Compile the Pake window around the local web UI port.
    system "pake",
           "http://127.0.0.1:#{WEB_PORT}/",
           "--name", APP_NAME,
           "--identifier", "com.omnirouter.desktop",
           "--width", "1280",
           "--height", "800",
           "--multi-window",
           "--no-restore-last-url",
           "--no-bundle"

    pake_binary = Pathname.glob(buildpath/"*-binary").first
    odie "Pake did not produce a standalone binary" if pake_binary.nil?
    libexec.install pake_binary => "omnirouter-desktop-app"

    share
    (share/"icons/hicolor/256x256/apps").mkpath

    (bin/"omnirouter-desktop").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="#{formula_opt_bin("node")}:${PATH}"

      APP_BIN="#{opt_libexec}/omnirouter-desktop-app"
      OMNI_BIN="#{opt_bin}/omnirouter"

      lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
      exec 9>"${lock_dir}/omnirouter-desktop-${UID}.lock"
      if ! flock -n 9; then
        echo "OmniRouter Desktop is already running." >&2
        exit 1
      fi

      PORT="#{WEB_PORT}" "${OMNI_BIN}" >/tmp/omnirouter-desktop.log 2>&1 &
      omni_pid=$!

      for _ in $(seq 1 100); do
        if (exec 3<>/dev/tcp/127.0.0.1/#{WEB_PORT}) 2>/dev/null; then break; fi
        sleep 0.2
      done

      "${APP_BIN}" "$@" &
      app_pid=$!
      wait "${app_pid}"
      kill "${omni_pid}" 2>/dev/null || true
    SH
    chmod 0755, bin/"omnirouter-desktop"

    (share/"applications").mkpath
    (share/"applications/omnirouter-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=OmniRouter
      Comment=OmniRouter web UI in an isolated desktop window
      Exec=#{opt_bin}/omnirouter-desktop %U
      Terminal=false
      Categories=Network;
      StartupWMClass=omnirouter
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/omnirouter-desktop.desktop",
            ".local/share/applications/omnirouter-desktop.desktop",
            source_base: :prefix,
            target_base: :home,
            overwrite:   true
  end

  def caveats
    <<~EOS
      Start the desktop app (starts omnirouter on port #{WEB_PORT}):

        omnirouter-desktop
    EOS
  end

  test do
    assert_predicate bin/"omnirouter", :executable?
    assert_predicate libexec/"omnirouter-desktop-app", :executable?
    assert_predicate bin/"omnirouter-desktop", :executable?
  end
end
