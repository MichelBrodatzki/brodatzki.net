<div align="center">
    <h1>monitoring1.netcup.brodatzki.network</h1>
    <p>
        netcup's VPS 200 G10s — 2 vCPU, 2 GiB RAM and 40 GiB SSD<br/>
    </p>
    <hr/><br/>
</div>

This VPS hosts the central monitoring stack for brodatzki.net. Logs and Metrics are received by VictoriaLogs and VictoriaMetrics respectively, displayed by Grafana and monitored by vmalert and AlertManager.

## Manual steps
The OAuth2 client secret for Grafana has to be put into `/var/lib/secrets/grafana-oidc-client-secret` by hand before the systemd service will start.