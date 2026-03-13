#!/bin/bash
helm repo add k8s_gateway https://k8s-gateway.github.io/k8s_gateway/
helm install exdns --values=values.yaml k8s_gateway/k8s-gateway
