class AoeDashboard < Formula
  desc "Web dashboard service for Agent of Empires"
  homepage "https://github.com/agent-of-empires/agent-of-empires"
  url "https://github.com/agent-of-empires/agent-of-empires/archive/refs/tags/v1.20.0.tar.gz"
  sha256 "fc83a9330807077a16df2c658d79535149fe0ec895299ace756f22096d13de70"
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

      This formula is not associated with, endorsed by, or affiliated with the
      upstream project. It is created purely for the author's own use. There is
      no expectation of support from the author of this package, nor from the
      authors of the packages referenced herein. Use at your own risk.
    EOS
  end

  test do
    assert_path_exists pkgshare/"README.md"
  end
end
