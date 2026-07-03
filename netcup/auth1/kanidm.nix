{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 8444 ];

  services.kanidm.package = pkgs.kanidm_1_10;
  services.kanidm.server = {
    enable = true;

    settings = {
      domain = "brodatzki.id";
      origin = "https://brodatzki.id";

      bindaddress = "127.0.0.1:8443";

      tls_chain = "/var/lib/kanidm/cert.pem";
      tls_key = "/var/lib/kanidm/key.pem";

      replication = {
        origin = "repl://core.brodatzki.id:8444";
        bindaddress = "0.0.0.0:8444";
      };
    };
  };

  security.acme.certs = {
    "brodatzki.id" = {
      postRun = ''
        cp -Lv {cert,key,chain}.pem /var/lib/kanidm/
        chown kanidm:kanidm /var/lib/kanidm/{cert,key,chain}.pem
        chmod 400 /var/lib/kanidm/{cert,key,chain}.pem
      '';
      reloadServices = ["kanidm.service"];
    };
  };
}