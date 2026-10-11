class CcrService < Formula
  desc "Service wrapper for claude-code-router (ccr) - router gateway and web UI"
  homepage "https://github.com/musistudio/claude-code-router"
  url "https://github.com/musistudio/claude-code-router/archive/refs/tags/v3.1.3.tar.gz"
  sha256 "95702f852632e0e33cdce9cd84968e4e093ad8e45133f9749cd429ea88473a8f"
  license "MIT"
  head "https://github.com/musistudio/claude-code-router.git", branch: "main"

  depends_on "claude-code-router"

  def install
    # Wrapper formula — the service definition is what matters.
    # Install a marker so the keg is not empty.
    (prefix/"INSTALL_RECEIPT.json").write "{}"
  end

  service do
    ccr_bin = "#{HOMEBREW_PREFIX}/opt/claude-code-router/bin/ccr"
    run [ccr_bin, "serve", "--no-open"]
    run_type :immediate
    keep_alive true
    working_dir Dir.home
    environment_variables PATH: std_service_path_env
    log_path var/"log/ccr.log"
    error_log_path var/"log/ccr.err"
  end

  def caveats
    <<~EOS
      Manage the Claude Code Router service with:

        brew services start ccr-service
        brew services stop ccr-service
        brew services restart ccr-service

      The web management UI will be available at http://127.0.0.1:3458
      and the model gateway at http://127.0.0.1:3456.

      Configuration lives in ~/.claude-code-router/. Open the web UI to add
      providers, then apply an Agent Config profile to connect Claude Code
      or other coding agents to the router.

      This service depends on claude-code-router (installed automatically).
    EOS
  end

  test do
    assert_path_exists prefix/"INSTALL_RECEIPT.json"
    assert_path_exists "#{HOMEBREW_PREFIX}/opt/claude-code-router/bin/ccr"
  end
end
