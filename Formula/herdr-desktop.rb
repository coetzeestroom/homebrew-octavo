class HerdrDesktop < Formula
  desc "Desktop app for the Herdr web UI"
  homepage "https://github.com/alecuba16/herdr-webui"
  url "https://github.com/alecuba16/herdr-webui/releases/download/v0.7.45/herdr-webui-linux-x86_64.tar.gz"
  version "0.7.45"
  sha256 "735cb2332693795b9de3e4bbaa356226f1e705c263360a529b75d3a176a2814b"
  license "MIT"

  depends_on :linux

  def install
    # Install the upstream prebuilt binaries.
    bin.install "herdr-webui"
    bin.install "herdr-webui-tui"

    # STUB: Pake/Tauri desktop window around http://127.0.0.1:8787 to be added,
    # mirroring deepseek-harness-desktop.rb.
    (libexec/"STUB").write <<~EOS
      herdr-desktop desktop window not yet implemented; the herdr-webui binary
      is installed and serves the web UI on port 8787.
    EOS
  end

  def caveats
    <<~EOS
      The Herdr WebUI binary is installed as `herdr-webui` (port 8787 by
      default) with the companion `herdr-webui-tui`.

      The desktop window wrapper is not yet implemented (see
      deepseek-harness-desktop for the target pattern).
    EOS
  end

  test do
    assert_predicate bin/"herdr-webui", :executable?
    assert_predicate bin/"herdr-webui-tui", :executable?
  end
end
