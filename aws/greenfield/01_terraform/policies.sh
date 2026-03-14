#!/usr/bin/env zsh
set -euo pipefail

printf '\033[0;35m%s\033[0m\n' "This script will deploy the policies from the policies/ directory to the corresponding IAM roles."

if [[ -z "${AWS_CLI_PROFILE:-}" ]]; then
	printf '\033[0;31m%s\033[0m\n' "ERROR: AWS_CLI_PROFILE is not set. Run this script via greenfield.sh or set AWS_CLI_PROFILE."
	exit 1
fi
aws_cli_profile="$AWS_CLI_PROFILE"

# Deploy policies from policies/ directory
script_dir="${0:a:h}"
policy_dir="$script_dir/policies"

for policy_file in "$policy_dir"/*.json; do
	role_name="${${policy_file:t}%.json}"
	access_level="${role_name##*-}"
	policy_name="terraform-managed-resources-${access_level}-access"

	printf '\033[0;32m%s\033[0m\n' "Processing role $role_name ..."

	# Verify role exists
	if ! aws iam get-role --role-name "$role_name" --profile "$aws_cli_profile" --no-cli-pager >/dev/null 2>&1; then
		printf '\033[0;31m%s\033[0m\n' "ERROR: Role $role_name does not exist. Skipping ..."
		continue
	fi

	# Check if the deployed policy matches the local policy
	deployed_policy=$(aws iam get-role-policy --role-name "$role_name" --policy-name "$policy_name" --profile "$aws_cli_profile" --no-cli-pager 2>/dev/null | jq -r '.PolicyDocument' 2>/dev/null || echo "")
	local_policy=$(jq -S '.' "$policy_file")

	if [[ -n "$deployed_policy" ]] && [[ "$(echo "$deployed_policy" | jq -S '.')" == "$local_policy" ]]; then
		printf '\033[0;33m%s\033[0m\n' "WARNING: Policy $policy_name on role $role_name is already up to date. Skipping ..."
	else
		printf '\033[0;32m%s\033[0m\n' "Deploying policy $policy_name to role $role_name ..."
		aws iam put-role-policy --role-name "$role_name" --policy-name "$policy_name" --policy-document "file://$policy_file" --profile "$aws_cli_profile"
		printf '\033[0;32m%s\033[0m\n' "Successfully deployed policy $policy_name to role $role_name."
	fi
done
