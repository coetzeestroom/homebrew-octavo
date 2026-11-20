class KiloDesktop < Formula
  desc "AI coding agent and interactive data science desktop app"
  homepage "https://kilo.ai"
  url "https://github.com/Kilo-Org/kilo-desktop/releases/download/v1.0.0/kilo-desktop_1.0.0_amd64.deb"
  sha256 "5d9d8b00ac958cba8722bce54eefc502a6fa092a5dad27cf34984800ed388b81"
  # OCVSAL 1.0 is source-available but not an SPDX identifier.
  license :cannot_represent

  livecheck do
    url "https://github.com/Kilo-Org/kilo-desktop/releases/latest"
    strategy :github_latest
  end

  depends_on "binutils" => :build
  depends_on "xz" => :build
  depends_on arch: :x86_64
  depends_on :linux

  def install
    # A .deb is an ar archive containing control.tar.* and data.tar.*.
    cd buildpath do
      system "ar", "x", cached_download
      data_tar = Dir["data.tar.*"].first
      odie "The Kilo Desktop .deb has no data archive" if data_tar.nil?
      system "tar", "-xf", data_tar
    end

    libexec.install Dir["usr/lib/kilo-desktop/*"]

    # Homebrew cannot install Electron's chrome-sandbox with root ownership,
    # so the launcher disables the setuid sandbox.
    (bin/"kilo-desktop").write <<~SH
      #!/usr/bin/env bash
      exec "#{opt_libexec}/kilo-desktop" --no-sandbox "$@"
    SH
    chmod 0755, bin/"kilo-desktop"

    (share/"icons/hicolor/1024x1024/apps").install \
      "usr/share/pixmaps/kilo-desktop.png" => "kilo-desktop.png"

    (share/"applications").mkpath
    (share/"applications/kilo-desktop.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=Kilo
      Comment=AI coding agent and interactive data science desktop
      Exec=#{opt_bin}/kilo-desktop %U
      Icon=#{opt_prefix}/share/icons/hicolor/1024x1024/apps/kilo-desktop.png
      Terminal=false
      Categories=Development;
      MimeType=x-scheme-handler/kilo-desktop;
      StartupWMClass=Kilo
    EOS
  end

  post_install_steps do
    mkdir_p ".local/share/applications", base: :home
    symlink "share/applications/kilo-desktop.desktop",
            ".local/share/applications/kilo-desktop.desktop",
            source_base: :prefix, target_base: :home, overwrite: true
  end

  def caveats
    <<~EOS
      Launch Kilo from the application menu or a terminal:

        kilo-desktop

      The launcher passes --no-sandbox because Homebrew cannot install
      Electron's SUID sandbox helper with root ownership. The app also uses
      the host GTK 3, NSS, libsecret, libnotify and AT-SPI libraries, which a
      normal desktop Linux installation already provides.

      The menu entry is linked into ~/.local/share/applications; remove it by
      hand after `brew uninstall`:

        rm -f ~/.local/share/applications/kilo-desktop.desktop
    EOS
  end

  test do
    assert_predicate bin/"kilo-desktop", :executable?
    assert_match "--no-sandbox", (bin/"kilo-desktop").read
    assert_predicate libexec/"kilo-desktop", :executable?
    assert_predicate libexec/"resources/app.asar", :file?
    assert_path_exists share/"applications/kilo-desktop.desktop"
  end
end
