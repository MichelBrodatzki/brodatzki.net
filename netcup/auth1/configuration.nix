{ ... }:

{
  imports =
    [ 
      /etc/nixos/hardware-configuration.nix
      ./locale.nix
      ./users.nix
      ./reverse-proxy.nix
      ./kanidm.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "auth1";
  networking.domain = "netcup.brodatzki.network";
  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  system.stateVersion = "26.05";
}
