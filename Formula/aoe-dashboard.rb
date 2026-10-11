class AoeDashboard < Formula
  desc "Web dashboard service for Agent of Empires"
  homepage "https://github.com/agent-of-empires/agent-of-empires"
  url "https://github.com/agent-of-empires/agent-of-empires/archive/refs/tags/v1.19.0.tar.gz"
  sha256 "2da687d59726f8c9a68741d09dd01bdcd591d752e5de47c45e28702d30762850"
  license "MIT"

  depends_on "aoe"

  def install
    # Wrapper formula — the service definition is what matters.
    # Install upstream documentation so the keg is not empty.
    pkgshare.install "README.md"
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
    assert_path_exists pkgshare/"README.md"
  end
end
