class CcrDesktop < Formula
  desc "Desktop app for the Claude Code Router (ccr) web UI"
  homepage "https://github.com/musistudio/claude-code-router"
  url "https://registry.npmjs.org/claude-code-router/-/claude-code-router-2.1.1.tgz"
  version "2.1.1"
  sha256 "0cf80f9e3153cd173d11b705d0c42ac9f4433dd1af94c8d6033bde0d2c984fd4"
  license "MIT"

  depends_on "claude-code-router"
  depends_on :linux

  def install
    # STUB: full Pake/Tauri desktop wrapper to be implemented, mirroring
    # deepseek-harness-desktop.rb (system deps, npm install, pake compile,
    # auth-redirect sidecar, launcher script, .desktop entry).
    (libexec/"STUB").write <<~EOS
      ccr-desktop is a stub pending completion of the deepseek-harness-desktop
      desktop-wrapper pattern.
    EOS
  end

  def caveats
    <<~EOS
      ccr-desktop is currently a stub and is not yet functional.

      Once implemented it will wrap the Claude Code Router web UI in a
      standalone desktop window, mirroring deepseek-harness-desktop.
    EOS
  end

  test do
    assert_path_exists libexec/"STUB"
  end
end
