#!/bin/bash

GITLAB_TOKEN=$(gopass show --yes --password brodatzkinet/ka1/gitlab-secrets-token)

if [[ -z $GITLAB_TOKEN ]]; then
	echo "Failed to retrieve GitLab token for secrets repo"
	exit 1
fi

kubectl create secret generic gitlab-secret --from-literal=token=$GITLAB_TOKEN --namespace=external-secrets
kubectl apply -f gitlab-store.yaml
