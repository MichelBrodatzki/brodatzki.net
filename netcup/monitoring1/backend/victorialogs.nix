{ ... }:

{
  services.victorialogs = {
    enable = true;
    listenAddress = "127.0.0.1:9428";
    extraOptions = [
      "-retentionPeriod=7d"
      "-retention.maxDiskSpaceUsageBytes=10GiB"
    ];
  };
}