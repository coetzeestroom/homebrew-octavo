class AoeDashboard < Formula
  desc "Web dashboard service for Agent of Empires"
  homepage "https://github.com/agent-of-empires/agent-of-empires"
  url "https://github.com/agent-of-empires/agent-of-empires/archive/refs/tags/v1.14.1.tar.gz"
  sha256 "6c24f7f537954b264048f514b5c74227162019ec8b514008883fc296ff71bc38"
  license "MIT"

  depends_on "aoe"

  def install
    # Wrapper formula — the service definition is what matters.
    # Install a marker so the keg is not empty.
    (prefix/"INSTALL_RECEIPT.json").write "{}"
  end

  service do
    run [formula_opt_bin("aoe")/"aoe", "serve", "--host", "127.0.0.1", "--port", "8080"]
    run_type :immediate
    keep_alive true
    working_dir Dir.home
    environment_variables PATH: "#{formula_opt_bin("aoe")}:#{std_service_path_env}"
    log_path var/"log/aoe-dashboard.log"
    error_log_path var/"log/aoe-dashboard.err"
  end

  def caveats
    <<~EOS
      Manage the Agent of Empires dashboard with:

        brew services start aoe-dashboard
        brew services stop aoe-dashboard
        brew services restart aoe-dashboard

      The dashboard listens on http://127.0.0.1:8080. AoE uses token
      authentication by default; run `aoe url` to print the authorized URL.
    EOS
  end

  test do
    assert_path_exists prefix/"INSTALL_RECEIPT.json"
  end
end
