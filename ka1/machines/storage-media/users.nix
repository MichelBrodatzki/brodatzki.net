{ pkgs, ... }:

{
    users.users.brodi = {
        isNormalUser = true;
        description = "Brodi";
        extraGroups = [ "networkmanager" "wheel" ];
        packages = with pkgs; [];
    };
}
