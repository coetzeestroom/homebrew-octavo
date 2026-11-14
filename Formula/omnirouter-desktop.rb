class OmnirouterDesktop < Formula
  desc "Desktop app for the OmniRouter web UI"
  homepage "https://github.com/Godde3s/omnirouter"
  url "https://github.com/Godde3s/omnirouter/releases/download/v1.4.0/dist-omnirouter-linux-amd64.tar.gz"
  version "1.4.0"
  sha256 "883d2ea6e7a3d9069a4e08f6883814d1db29afb3901d9a7e12bd748349f4b488"
  license "MIT"

  depends_on :linux

  def install
    # Install the upstream Go binary (single static executable).
    bin.install "omnirouter-linux-amd64" => "omnirouter"

    # STUB: Pake/Tauri desktop window around http://127.0.0.1:8080 to be added,
    # mirroring deepseek-harness-desktop.rb (system deps, pake compile,
    # auth-redirect sidecar, launcher script, .desktop entry).
    (libexec/"STUB").write <<~EOS
      omnirouter-desktop desktop window not yet implemented; the omnirouter
      binary is installed and serves the web UI on port 8080.
    EOS
  end

  def caveats
    <<~EOS
      The OmniRouter binary is installed as `omnirouter` and serves its web UI
      on http://127.0.0.1:8080 by default.

      The desktop window wrapper is not yet implemented (see
      deepseek-harness-desktop for the target pattern).
    EOS
  end

  test do
    assert_predicate bin/"omnirouter", :executable?
  end
end
