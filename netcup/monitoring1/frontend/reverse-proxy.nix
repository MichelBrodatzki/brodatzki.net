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
          proxyPass = "http://127.0.0.1:8428";
          extraConfig = ''
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
            client_max_body_size 32m;
            proxy_request_buffering off;
          '';
        };

        locations."/".return = "404";
      };
    };
  };
}