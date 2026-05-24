{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mergerfs
  ];

  fileSystems."/mnt/disks/parity1" =
    { 
      device = "/dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VDKU87GK-part1";
      fsType = "ext4";
    };

  fileSystems."/mnt/disks/data1" =
    { 
      device = "/dev/disk/by-id/ata-WDC_WD80EDBZ-11B0ZA0_VRJWLS1K-part1";
      fsType = "ext4";
    };

  fileSystems."/mnt/pool" =
    {
      depends = 
        [
          "/mnt/disks/data1"
        ];
      device = "/mnt/disks/data*";
      fsType = "mergerfs";
      options = ["cache.files=off" "category.create=pfrd" "func.getattr=newest" "dropcacheonclose=false"];  
    };

  services.snapraid = 
    {  
      enable = true;
      parityFiles =
        [
          "/mnt/disks/parity1/.snapraid.1.parity"
        ];
      contentFiles =
        [
          "/var/.snapraid.content"
          "/mnt/disks/data1/.snapraid.1.content"
        ];
      dataDisks =
        {
           d1 = "/mnt/disks/data1";
        };
      touchBeforeSync = true;
      sync.interval = "daily";
      scrub = {
        interval = "weekly";
        plan = 10;
      };
    };

  services.udev.extraRules = 
    let
      mkRule = as: lib.concatStringsSep ", " as;
      mkRules = rs: lib.concatStringsSep "\n" rs;
    in mkRules ([( mkRule [
      ''ACTION=="add|change"''
      ''SUBSYSTEM=="block"''
      ''KERNEL=="sd[a-z]"''
      ''ATTR{queue/rotational}=="1"''
      ''RUN+="${pkgs.hdparm}/bin/hdparm -B 127 -S 120 /dev/%k"''
    ])]);
}
