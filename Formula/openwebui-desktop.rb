class OpenwebuiDesktop < Formula
  desc "Desktop app for Open WebUI"
  homepage "https://github.com/open-webui/open-webui"
  # STUB: open-webui is distributed via pip/docker; a Homebrew-friendly source
  # archive or wheel URL will be pinned here once the wrapper is implemented.
  url "https://example.com/openwebui-desktop-stub.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on :linux
  depends_on "python@3.12"

  def install
    # STUB: full Pake/Tauri desktop wrapper to be implemented, mirroring
    # deepseek-harness-desktop.rb.
    (libexec/"STUB").write <<~EOS
      openwebui-desktop is a stub pending completion of the deepseek-harness-desktop
      desktop-wrapper pattern.
    EOS
  end

  def caveats
    <<~EOS
      openwebui-desktop is currently a stub and is not yet functional.

      Once implemented it will wrap the Open WebUI in a standalone desktop
      window, mirroring deepseek-harness-desktop.
    EOS
  end

  test do
    assert_path_exists libexec/"STUB"
  end
end
