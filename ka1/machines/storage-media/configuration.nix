{ ... }:

{
  imports =
    [ 
      /etc/nixos/hardware-configuration.nix
      ./locale.nix
      ./users.nix
      ./storage.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "storage-media";
  networking.networkmanager.enable = true;

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
