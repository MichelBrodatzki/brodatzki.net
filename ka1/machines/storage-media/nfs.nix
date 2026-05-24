{ lib, ... }:

{
  services.nfs.server = { 
    enable = true;
    exports = 
      let
        mkExports = rs: lib.concatStringsSep "\n" rs;
      in mkExports ([
        "/mnt/pool/media            10.10.40.100(ro,fsid=0,hide) 10.10.40.110(ro,fsid=0,hide)"
        "/mnt/pool/media/movies     10.10.40.100(ro,nohide) 10.10.40.110(ro,nohide)"
        "/mnt/pool/media/series     10.10.40.100(ro,nohide) 10.10.40.110(ro,nohide)"
        "/mnt/pool/media/music      10.10.40.100(ro,nohide) 10.10.40.110(ro,nohide)"
        "/mnt/pool/media/audiobooks 10.10.40.100(ro,nohide) 10.10.40.110(ro,nohide)"
      ]);
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
}
