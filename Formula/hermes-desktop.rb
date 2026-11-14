class HermesDesktop < Formula
  desc "Desktop app for the Hermes Agent web UI"
  homepage "https://hermes-agent.nousresearch.com"
  # Reuses the hermes-agent source archive as the formula payload (the real
  # desktop wrapper will depend on the hermes-agent formula instead).
  url "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.9.24.tar.gz"
  version "2026.9.24"
  sha256 "15b15ce4e6ec8ea424a081823709d1e17f0943e7b42b59597d24ebb94cbd1742"
  license "MIT"

  depends_on "hermes-agent"
  depends_on :linux

  def install
    # STUB: full Pake/Tauri desktop wrapper to be implemented, mirroring
    # deepseek-harness-desktop.rb. Note: hermes-dashboard.rb already provides a
    # brew services wrapper; this formula is the desktop-window variant.
    (libexec/"STUB").write <<~EOS
      hermes-desktop is a stub pending completion of the deepseek-harness-desktop
      desktop-wrapper pattern.
    EOS
  end

  def caveats
    <<~EOS
      hermes-desktop is currently a stub and is not yet functional.

      Once implemented it will wrap the Hermes Agent web UI in a standalone
      desktop window, mirroring deepseek-harness-desktop. For the service
      (headless) variant see hermes-dashboard.
    EOS
  end

  test do
    assert_path_exists libexec/"STUB"
  end
end
