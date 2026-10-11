class HermesDashboard < Formula
  desc "Web Dashboard for Hermes Agent - config, API keys, sessions"
  homepage "https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard"
  url "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.8.31.tar.gz"
  sha256 "78fb3ff707ec1d17044b875ecac8bef28aa39d44242824f6871ca40afe7bf217"
  license "MIT"
  head "https://github.com/NousResearch/hermes-agent.git", branch: "main"

  depends_on "hermes-agent"

  def install
    # Wrapper formula — the service definition is what matters.
    # Install a marker so the keg is not empty.
    (prefix/"INSTALL_RECEIPT.json").write "{}"
  end

  service do
    hermes_bin = "#{Dir.home}/.hermes/hermes-agent/venv/bin/hermes"
    hermes_home = "#{Dir.home}/.hermes"
    hermes_venv = "#{hermes_home}/hermes-agent/venv"
    dash_path = "#{hermes_venv}/bin:#{hermes_home}/hermes-agent/node_modules/.bin" \
                ":#{hermes_home}/node/bin:#{Dir.home}/.local/bin:#{std_service_path_env}"
    run [hermes_bin, "dashboard", "--port", "9119", "--host", "127.0.0.1", "--no-open", "--insecure"]
    run_type :immediate
    keep_alive true
    working_dir hermes_home
    environment_variables(
      PATH:        dash_path,
      VIRTUAL_ENV: hermes_venv,
      HERMES_HOME: hermes_home,
    )
    log_path var/"log/hermes-dashboard.log"
    error_log_path var/"log/hermes-dashboard.err"
  end

  def caveats
    <<~EOS
      Manage the Hermes Dashboard with:

        brew services start hermes-dashboard
        brew services stop hermes-dashboard
        brew services restart hermes-dashboard

      The dashboard will be available at http://127.0.0.1:9119.

      This service depends on hermes-agent (installed separately).
    EOS
  end

  test do
    assert_path_exists prefix/"INSTALL_RECEIPT.json"
  end
end
