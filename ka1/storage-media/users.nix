{ pkgs, ... }:

{
    users.users.brodi = {
        isNormalUser = true;
        description = "Brodi";
        extraGroups = [ "networkmanager" "wheel" ];
        packages = with pkgs; [];
        openssh.authorizedKeys.keys = [ 
		"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhhYovpLzYjK9aosVEeIiEcsyzxRBDFIbiT+tG90Arc brodatzki.net - michel@brodatzki.com - MacBook" 
	];
    };
}
