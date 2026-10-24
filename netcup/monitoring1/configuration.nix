{ ... }:

{
  imports =
    [ 
      /etc/nixos/hardware-configuration.nix
      ../../_shared/nixos/base.nix
      ./backend/victoriametrics.nix
      ./backend/victorialogs.nix
      ./frontend/grafana.nix
      ./frontend/reverse-proxy.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "monitoring1";
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
