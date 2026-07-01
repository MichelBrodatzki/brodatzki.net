{ config, ... }:

{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "michel+acme@brodatzki.com";

  services.nginx = {
    enable = true;

    virtualHosts."brodatzki.id" = {
      forceSSL = true;
      enableACME = true;
      serverAliases = [ "core.brodatzki.id" ];

      locations."/" = {
        proxyPass = "https://127.0.0.1:8443";
      };
    };
  };
}