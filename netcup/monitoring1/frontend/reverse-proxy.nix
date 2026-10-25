{ config, ... }:

let
  monitoringClientCA = ../pki/monitoring-client-ca.cert.pem;
  requireClientCertificate = ''
    ssl_client_certificate ${monitoringClientCA};
    ssl_verify_client on;
    ssl_verify_depth 1;
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "michel+acme@brodatzki.com";

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    commonHttpConfig = ''
      map $ssl_client_s_dn $tenant_name {
        default "";
        "CN=ka1-alloy" "ka1";
      }

      map $ssl_client_s_dn $tenant_account_id {
        default "";
        "CN=ka1-alloy" "1";
      }
    '';

    virtualHosts = {
      "monitoring.brodatzki.net" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
        };
      };

      "metrics.ingest.monitoring.brodatzki.net" = {
        forceSSL = true;
        enableACME = true;
        extraConfig = requireClientCertificate;

        locations."= /api/v1/write" = {
          proxyPass = "http://127.0.0.1:8428/api/v1/write?extra_label=tenant=$tenant_name";
          extraConfig = ''
            if ($tenant_name = "") {
              return 403;
            }

            client_max_body_size 32m;
            proxy_request_buffering off;
          '';
        };

        locations."/".return = "404";
      };

      "logs.ingest.monitoring.brodatzki.net" = {
        forceSSL = true;
        enableACME = true;
        extraConfig = requireClientCertificate;

        locations."= /insert/loki/api/v1/push" = {
          proxyPass = "http://127.0.0.1:9428";
          extraConfig = ''
            if ($tenant_account_id = "") {
              return 403;
            }

            proxy_set_header AccountID $tenant_account_id;
            proxy_set_header ProjectID 0;

            client_max_body_size 32m;
            proxy_request_buffering off;
          '';
        };

        locations."/".return = "404";
      };
    };
  };
}