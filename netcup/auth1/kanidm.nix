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

        "repl://ka1.brodatzki.id:8444" = {
          type = "allow-pull";
          consumer_cert = "MIIB2DCCAX6gAwIBAgIRAXFMxmhzRE5xm9H7387lFuUwCgYIKoZIzj0EAwIwTDEtMCsGA1UEAwwkNzE0Y2M2NjgtNzM0NC00ZTcxLTliZDEtZmJkZmNlZTUxNmU1MRswGQYDVQQKDBJLYW5pZG0gUmVwbGljYXRpb24wHhcNMjYwNzAzMTgwMDMzWhcNMzAwNzAzMTgwMDMzWjBMMS0wKwYDVQQDDCQ3MTRjYzY2OC03MzQ0LTRlNzEtOWJkMS1mYmRmY2VlNTE2ZTUxGzAZBgNVBAoMEkthbmlkbSBSZXBsaWNhdGlvbjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABDZAQnNr-biNaTSQvF8RPcoopJJ6taVjwa1_k4TL9BXjnaIeKG21AbiuC64FBNt0-i26h1hMBY9oDkBlut1q6qajQTA_MCAGA1UdJQEB_wQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATAbBgNVHREEFDASghBrYTEuYnJvZGF0emtpLmlkMAoGCCqGSM49BAMCA0gAMEUCIQCT1dQJ6-zIc6sqTLB9equhJp7Ovi5I5B-XwrpwKwRZ3gIgb1fJG1asJ1ZfQI15bQ1gG-Uo66hCQFgCUsSkQ9NzE3s";
        };
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