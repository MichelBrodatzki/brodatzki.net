#!/usr/bin/env zsh
set -euo pipefail

printf '\033[0;35m%s\033[0m\n' "This script will create the ka1 OIDC identity provider that workloads on kube1 use to assume AWS IAM roles."

if [[ -z "${AWS_CLI_PROFILE:-}" ]]; then
	printf '\033[0;31m%s\033[0m\n' "ERROR: AWS_CLI_PROFILE is not set. Run this script via greenfield.sh or set AWS_CLI_PROFILE."
	exit 1
fi
aws_cli_profile="$AWS_CLI_PROFILE"

ka1_oidc_url="https://raw.githubusercontent.com/MichelBrodatzki/brodatzki.net/main/.static/ka1"

# Create ka1 IdP provider
if aws iam list-open-id-connect-providers --profile "$aws_cli_profile" | jq -e --arg url "${ka1_oidc_url#https://}" '[.OpenIDConnectProviderList[].Arn] | any(. | endswith($url))' >/dev/null 2>&1; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: ka1 OIDC provider already exists. Skipping creating ..."
else
	printf '\033[0;32m%s\033[0m\n' "ka1 OIDC provider doesn't exist. Creating ..."
	aws iam create-open-id-connect-provider --url "$ka1_oidc_url" --client-id-list "sts.amazonaws.com" --no-cli-pager --profile "$aws_cli_profile"
fi
