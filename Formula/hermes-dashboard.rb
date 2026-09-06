class HermesDashboard < Formula
  desc "Systemd service unit for the Hermes Agent Web Dashboard"
  homepage "https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard"
  url "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.8.31.tar.gz"
  sha256 "78fb3ff707ec1d17044b875ecac8bef28aa39d44242824f6871ca40afe7bf217"
  license "MIT"
  head "https://github.com/NousResearch/hermes-agent.git", branch: "main"

  depends_on "hermes-agent"

  def install
    (prefix/"lib/systemd/user").mkpath
    (prefix/"lib/systemd/user/hermes-dashboard.service").write <<~SERVICE
      [Unit]
      Description=Hermes Agent Web Dashboard - Config, API keys, sessions
      After=network-online.target
      Wants=network-online.target
      Wants=hermes-gateway.service
      BindsTo=hermes-gateway.service
      After=hermes-gateway.service
      PartOf=hermes-gateway.service

      [Service]
      Type=simple
      ExecStart=%h/.hermes/hermes-agent/venv/bin/hermes dashboard --port 9119 --host 127.0.0.1 --no-open --insecure
      ExecStop=%h/.hermes/hermes-agent/venv/bin/hermes dashboard --stop
      WorkingDirectory=%h/.hermes
      Environment="PATH=%h/.hermes/hermes-agent/venv/bin:%h/.hermes/hermes-agent/node_modules/.bin:%h/.hermes/node/bin:%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      Environment="VIRTUAL_ENV=%h/.hermes/hermes-agent/venv"
      Environment="HERMES_HOME=%h/.hermes"
      Restart=on-failure
      RestartSec=5
      KillMode=mixed
      KillSignal=SIGTERM
      TimeoutStopSec=60
      StandardOutput=journal
      StandardError=journal

      [Install]
      WantedBy=default.target
    SERVICE
  end

  def caveats
    <<~EOS
      To enable the Hermes Dashboard service, run:

        systemctl --user daemon-reload
        systemctl --user enable #{opt_prefix}/lib/systemd/user/hermes-dashboard.service
        systemctl --user start hermes-dashboard.service

      The dashboard will be available at http://127.0.0.1:9119.

      This service depends on hermes-gateway.service and hermes-agent
      (installed separately).
    EOS
  end

  test do
    assert_path_exists prefix/"lib/systemd/user/hermes-dashboard.service"
  end
end
