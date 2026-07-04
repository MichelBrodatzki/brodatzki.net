#/usr/bin/env bash
curl -s https://letsencrypt.org/certs/isrgrootx1.pem https://letsencrypt.org/certs/isrg-root-x2.pem > ca.crt
kubectl create configmap kanidm-backend-ca -n kanidm --from-file=ca.crt --dry-run=client -o yaml
rm ca.crt