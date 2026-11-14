
Design Document: Cross-Distro Isolated Web App Packaging via Pake and Homebrew


1. Overview & Architecture

This document outlines a declarative, cross-distribution architecture for packaging any web application into an isolated, lightweight native Linux executable (~5–10 MB) managed entirely via a Brewfile.
Instead of relying on heavy Electron wrappers or FUSE-dependent AppImages, this pipeline uses Pake (built on Tauri and WebKitGTK) compiled locally inside a custom Homebrew Formula.

Key Architectural Pillars

• Session Isolation: Tauri/WebKitGTK stores cookies, localStorage, and IndexedDB in a dedicated app-scoped XDG directory (~/.local/share/<bundle-id>), completely isolated from your primary web browser.
• Cross-Distro Portability: By instructing Pake to emit a raw, unbundled binary (--no-bundle) or extracting a distro-agnostic archive (--targets zst), the Formula avoids dpkg-deb or rpm2cpio dependencies—allowing identical execution across Arch Linux, Ubuntu/Debian, and Fedora/RHEL.
• Process Lifecycle Hygiene: A lightweight POSIX wrapper script tracks the GUI window's Process ID (PID) and enforces a trap cleanup routine so closing the window immediately terminates orphaned WebKitWebProcess and WebKitNetworkProcess children.
┌─────────────┐     ┌──────────────────────────────────────────────────────────┐
│  Brewfile   │────▶│  Homebrew Formula (Formula/my-webapp.rb)                 │
└─────────────┘     │  1. Installs Node & Rust build toolchain                 │
                    │  2. Compiles standalone ELF binary via pake-cli          │
                    │  3. Installs binary to #{libexec}/my-webapp-bin          │
                    │  4. Writes PID-tracked wrapper to #{bin}/my-webapp       │
                    │  5. Generates & links XDG .desktop entry + icon          │
                    └──────────────────────────────────────────────────────────┘

2. Host System Prerequisites (By Distribution)

While Homebrew provides node and rust at build time, Tauri links dynamically against the host operating system's native GTK and WebKitGTK shared libraries. Install these system headers once per machine before running brew bundle:

Distribution	System Dependency Installation Command
Arch Linux	sudo pacman -S --needed webkit2gtk-4.1 base-devel curl wget file openssl appmenu-gtk-module libappindicator-gtk3 librsvg xdotool
Ubuntu / Debian	sudo apt update && sudo apt install -y libwebkit2gtk-4.1-dev build-essential curl wget file libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev
Fedora / RHEL	sudo dnf install -y webkit2gtk4.1-devel openssl-devel curl wget file libappindicator-gtk3-devel librsvg2-devel libxdo-devel @development-tools


3. Repository & Tap Structure

Create a GitHub repository prefixed with homebrew- (e.g., github.com/<YOUR_USER>/homebrew-webapps). Homebrew automatically maps tap "<YOUR_USER>/webapps" to this repository.
text
homebrew-webapps/
├── Formula/
│   └── my-webapp.rb       # Self-compiling Homebrew Formula
└── Brewfile               # Declarative manifest for target machines
Use code with caution.

4. Complete Homebrew Formula Implementation

Save the following code to Formula/my-webapp.rb. It includes inline documentation for Pake's customization flags and handles compilation, wrapper generation, and XDG desktop integration in a single pass.
ruby
class MyWebapp < Formula
  desc "Isolated Pake desktop wrapper for MyWebApp"
  homepage "https://your-webapp-url.com"
  # Pake CLI fetches the upstream Tauri template dynamically during npm install.
  # Using a lightweight anchor URL satisfies Homebrew's Formula download audit.
  url "https://github.com"
  sha256 "SKIP" # Replace with actual tarball sha256 if publishing to a public tap
  license "MIT"

  depends_on "node" => :build
  depends_on "rust" => :build
  depends_on :linux

  def install
    # 1. Install pake-cli locally inside Homebrew's isolated build sandbox
    system "npm", "install", "pake-cli@latest"
    pake_bin = buildpath/"node_modules/.bin/pake"

    # 2. Compile the standalone ELF binary using Pake CLI flags
    # Refer to Pake's CLI Usage Guide for all available options:
    # https://github.com/tw93/Pake/blob/main/docs/cli-usage.md
    pake_args = [
      "https://your-webapp-url.com",

      # --name: Sets the application display name and output binary filename.
      "--name", "MyWebApp",

      # --icon: Path or URL to a .png/.ico icon. If omitted, Pake auto-fetches
      # the target website's favicon/apple-touch-icon automatically.
      # "--icon", "https://your-webapp-url.com",

      # --width / --height: Initial window dimensions in pixels (defaults: 1200x780).
      "--width", "1280",
      "--height", "800",

      # --hide-window-decorations: Removes native OS title bars/borders on Linux/Windows
      # for a sleek, minimal frameless window.
      # "--hide-window-decorations",

      # --dark-mode: Forces WebKitGTK to prefer dark color schemes (@media prefers-color-scheme: dark).
      "--dark-mode",

      # --multi-window: Allows the web app to open secondary windows (essential for
      # OAuth/SSO popups like Google, GitHub, or Okta login flows).
      "--multi-window",

      # --incognito: Launches with an ephemeral session that wipes cookies/storage on exit.
      # Omit this flag to keep a persistent, isolated login session across restarts.
      # "--incognito",

      # --user-agent: Overrides the default WebKitGTK user agent string if a site
      # blocks embedded webviews or serves degraded mobile layouts.
      # "--user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",

      # --no-bundle: Skips distro-specific packaging (.deb/.rpm) and outputs the raw
      # compiled Rust/Tauri ELF executable directly—ideal for cross-distro Homebrew installs.
      "--no-bundle"
    ]

    system pake_bin, *pake_args

    # 3. Locate and install the compiled ELF binary into libexec
    # Storing the raw binary in libexec keeps it off $PATH so users always invoke
    # our PID-managed wrapper script in #{bin} instead.
    compiled_elf = Dir["**/release/my-webapp", "**/release/MyWebApp", "./my-webapp", "./MyWebApp"].find do |f|
      File.file?(f) && File.executable?(f)
    end
    odie "Failed to locate compiled Pake ELF binary" unless compiled_elf

    libexec.install compiled_elf => "my-webapp-bin"

    # Install icon if Pake downloaded/generated one during build
    icon_src = Dir["**/icons/icon.png", "**/icons/128x128.png", "**/*.png"].first
    if icon_src
      (share/"icons/hicolor/256x256/apps").install icon_src => "my-webapp.png"
    end

    # 4. Generate the process-clean wrapper script in Homebrew's bin directory
    (bin/"my-webapp").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail

      # Wayland/Nvidia compatibility safeguard (optional: uncomment if WebKit renders blank)
      # export WEBKIT_DISABLE_DMABUF_RENDERER=1

      # Launch the compiled Tauri/WebKitGTK binary in the background and capture its PID
      "#{libexec}/my-webapp-bin" "$@" &
      APP_PID=$!

      # Terminate the main process and any spawned WebKit child processes on exit
      cleanup() {
        kill -TERM "$APP_PID" 2>/dev/null || true
        pkill -P "$APP_PID" 2>/dev/null || true
      }
      trap cleanup EXIT INT TERM

      # Block until the GUI window closes
      wait "$APP_PID"
    EOS
    chmod 0755, bin/"my-webapp"

    # 5. Generate the XDG .desktop launcher inside Homebrew's share directory
    (share/"applications").mkpath
    (share/"applications/my-webapp.desktop").write <<~EOS
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=MyWebApp
      Comment=Isolated Pake Web App
      Exec=#{bin}/my-webapp %U
      Icon=#{share}/icons/hicolor/256x256/apps/my-webapp.png
      Terminal=false
      Categories=Network;WebBrowser;
      StartupWMClass=my-webapp
    EOS
  end

  def post_install
    # Symlink the .desktop entry into the user's XDG applications directory so desktop
    # environments (GNOME, KDE, Hyprland/rofi, XFCE) index it immediately.
    user_apps = Pathname.new("#{Dir.home}/.local/share/applications")
    user_apps.mkpath
    ln_sf share/"applications/my-webapp.desktop", user_apps/"my-webapp.desktop"
  end

  def caveats
    <<~EOS
      MyWebApp has been compiled and linked to your desktop launcher.
      To remove the desktop menu symlink upon uninstalling, run:
        rm -f ~/.local/share/applications/my-webapp.desktop
    EOS
  end

  test do
    assert_predicate libexec/"my-webapp-bin", :executable?
    assert_predicate bin/"my-webapp", :executable?
  end
end
Use code with caution.

5. Declarative Brewfile Usage

Add your custom tap and formula to your system's Brewfile:
ruby
tap "YOUR_USER/webapps", "https://github.com"

# Compiles the Pake ELF binary, installs the wrapper script, and links the .desktop entry
brew "YOUR_USER/webapps/my-webapp"
Use code with caution.

Operational Commands

• Initial Install: brew bundle install
• Recompile After Changing Flags/URL: brew reinstall YOUR_USER/webapps/my-webapp
• Clean Uninstall: brew uninstall my-webapp && rm -f ~/.local/share/applications/my-webapp.desktop

6. Cross-Distro Considerations & Troubleshooting

1. Wayland / NVIDIA Blank Windows: On Arch or Fedora running Wayland with proprietary NVIDIA drivers, WebKitGTK may occasionally render a blank white window due to DMA-BUF compositing bugs. Uncommenting export WEBKIT_DISABLE_DMABUF_RENDERER=1 inside the wrapper script in Formula/my-webapp.rb resolves this across all distros.
2. Build Caching / Speed: Homebrew cleans up buildpath after each install, meaning cargo recompiles dependencies on brew reinstall. If you later want instant installs across multiple machines, you can migrate the build step to a GitHub Actions workflow that uploads the compiled my-webapp-bin to a GitHub Release and switches the Formula to download that pre-built artifact.

7. References

• Pake GitHub Repository & CLI Options: tw93/Pake CLI Usage Guide
• Pake Linux FAQ & WebKit Rendering Flags: tw93/Pake FAQ
• Homebrew Formula Cookbook: Homebrew Documentation
• Tauri Linux System Dependencies: Tauri Prerequisites
If you'd like to expand this setup, I can provide:
• A parameterized Ruby helper so you can spin up multiple web apps in your tap (e.g., gmail-app.rb, linear-app.rb) without duplicating the Formula boilerplate
• A GitHub Actions CI pipeline to pre-compile the ELF binary on Ubuntu when you're ready to optimize install speed
