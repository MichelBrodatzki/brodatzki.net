{ lib, ... }:

{
  services.nfs.server = { 
    enable = true;
    exports = 
      let
        mkExports = rs: lib.concatStringsSep "\n" rs;
      in mkExports ([
        "/mnt/pool/media/movies     10.10.40.100(ro) 10.10.40.110(ro)"
        "/mnt/pool/media/series     10.10.40.100(ro) 10.10.40.110(ro)"
        "/mnt/pool/media/music      10.10.40.100(ro) 10.10.40.110(ro)"
        "/mnt/pool/media/audiobooks 10.10.40.100(ro) 10.10.40.110(ro)"
      ]);
  };
}
