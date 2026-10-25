{ pkgs, ... }:

{
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        enforce_domain = true;
        enable_gzip = true;
        domain = "monitoring.brodatzki.net";
        root_url = "https://monitoring.brodatzki.net";
      };

      security = {
        secret_key = "$__file{/run/credentials/grafana.service/secret_key}";
        disable_initial_admin_creation = true;
        cookie_secure = true;
        cookie_samesite = "lax";
      };

      auth = {
        disable_login_form = true;
      };

      "auth.generic_oauth" = {
        enabled = true;
        auto_login = false;
        name = "Brodatzki ID";

        client_id = "grafana";
        client_secret = "$__file{/run/credentials/grafana.service/grafana_oidc_client_secret}";

        scopes = "openid profile email groups";
        
        auth_url = "https://brodatzki.id/ui/oauth2";
        token_url = "https://brodatzki.id/oauth2/token";
        api_url = "https://brodatzki.id/oauth2/openid/grafana/userinfo";

        use_pkce = true;
        use_refresh_token = true;
        allow_sign_up = true;

        login_attribute_path = "preferred_username";
        groups_attribute_path = "groups";

        role_attribute_path = "contains(grafana_role[*], 'GrafanaAdmin') && 'GrafanaAdmin' || contains(grafana_role[*], 'Admin') && 'Admin' || contains(grafana_role[*], 'Editor') && 'Editor' || 'Viewer'";
        allow_assign_grafana_admin = true;
      };

      analytics.reporting_enabled = false;
    };

    declarativePlugins = with pkgs.grafanaPlugins; [
      # default plugins for explore page
      grafana-metricsdrilldown-app
      grafana-lokiexplore-app
      grafana-exploretraces-app
      grafana-pyroscope-app
      
      # victoriametrics datasource plugins
      victoriametrics-metrics-datasource
      victoriametrics-logs-datasource
    ];

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "VictoriaMetrics";
          type = "victoriametrics-metrics-datasource";
          access = "proxy";
          url = "http://127.0.0.1:8428";
          isDefault = true;
        }
        {
          name = "VictoriaLogs";
          type = "victoriametrics-logs-datasource";
          access = "proxy";
          url = "http://127.0.0.1:9428";
          isDefault = false;
        }
      ];
    };
  };

  systemd.services.grafana.serviceConfig = {
    LoadCredential = [
      "grafana_oidc_client_secret:/var/lib/secrets/grafana_oidc_client_secret"
      "secret_key:/var/lib/secrets/grafana_secret_key"
    ];

    ExecStartPre = [
      "${pkgs.coreutils}/bin/test -s /run/credentials/grafana.service/grafana_oidc_client_secret"
      "${pkgs.coreutils}/bin/test -s /run/credentials/grafana.service/secret_key"
    ];
  };

}