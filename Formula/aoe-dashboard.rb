class AoeDashboard < Formula
  desc "Web dashboard service for Agent of Empires"
  homepage "https://github.com/agent-of-empires/agent-of-empires"
  url "https://github.com/agent-of-empires/agent-of-empires/archive/refs/tags/v1.21.0.tar.gz"
  sha256 "0d9a2da8ab5d99452174626d83d7804988051630bdcb408f9abe6e81d56a15e9"
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
