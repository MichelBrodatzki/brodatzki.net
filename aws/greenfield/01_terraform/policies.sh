#!/usr/bin/env zsh
set -euo pipefail

printf '\033[0;35m%s\033[0m\n' "This script will deploy the policies from the policies/ directory to the corresponding IAM roles."

if [[ -z "${AWS_CLI_PROFILE:-}" ]]; then
	printf '\033[0;31m%s\033[0m\n' "ERROR: AWS_CLI_PROFILE is not set. Run this script via greenfield.sh or set AWS_CLI_PROFILE."
	exit 1
fi
aws_cli_profile="$AWS_CLI_PROFILE"

script_dir="${0:a:h}"
boundary_dir="$script_dir/boundaries"
policy_dir="$script_dir/policies"
aws_account_id=$(aws sts get-caller-identity --query Account --output text --profile "$aws_cli_profile")

# Permissions boundaries are deliberately managed by this privileged bootstrap
# script rather than by the GitHub Actions role they constrain.
for boundary_file in "$boundary_dir"/*.json; do
	role_name="${${boundary_file:t}%.json}"
	boundary_name="terraform-boundary-$role_name"
	boundary_arn="arn:aws:iam::$aws_account_id:policy/$boundary_name"

	printf '\033[0;32m%s\033[0m\n' "Processing permissions boundary $boundary_name ..."

	if ! aws iam get-policy --policy-arn "$boundary_arn" --profile "$aws_cli_profile" --no-cli-pager >/dev/null 2>&1; then
		aws iam create-policy \
			--policy-name "$boundary_name" \
			--description "Maximum permissions for Terraform-managed role $role_name" \
			--policy-document "file://$boundary_file" \
			--profile "$aws_cli_profile" \
			--no-cli-pager >/dev/null
		printf '\033[0;32m%s\033[0m\n' "Created permissions boundary $boundary_name."
	else
		default_version_id=$(aws iam get-policy --policy-arn "$boundary_arn" --profile "$aws_cli_profile" --no-cli-pager | jq -r '.Policy.DefaultVersionId')
		deployed_boundary=$(aws iam get-policy-version --policy-arn "$boundary_arn" --version-id "$default_version_id" --profile "$aws_cli_profile" --no-cli-pager | jq -S '.PolicyVersion.Document')
		local_boundary=$(jq -S '.' "$boundary_file")

		if [[ "$deployed_boundary" == "$local_boundary" ]]; then
			printf '\033[0;33m%s\033[0m\n' "WARNING: Permissions boundary $boundary_name is already up to date. Skipping policy update ..."
		else
			version_count=$(aws iam list-policy-versions --policy-arn "$boundary_arn" --profile "$aws_cli_profile" --no-cli-pager | jq '.Versions | length')
			if (( version_count >= 5 )); then
				oldest_version_id=$(aws iam list-policy-versions --policy-arn "$boundary_arn" --profile "$aws_cli_profile" --no-cli-pager | jq -r '[.Versions[] | select(.IsDefaultVersion == false)] | sort_by(.CreateDate) | .[0].VersionId')
				aws iam delete-policy-version --policy-arn "$boundary_arn" --version-id "$oldest_version_id" --profile "$aws_cli_profile" --no-cli-pager
			fi

			aws iam create-policy-version \
				--policy-arn "$boundary_arn" \
				--policy-document "file://$boundary_file" \
				--set-as-default \
				--profile "$aws_cli_profile" \
				--no-cli-pager >/dev/null
			printf '\033[0;32m%s\033[0m\n' "Updated permissions boundary $boundary_name."
		fi
	fi

	if aws iam get-role --role-name "$role_name" --profile "$aws_cli_profile" --no-cli-pager >/dev/null 2>&1; then
		deployed_boundary_arn=$(aws iam get-role --role-name "$role_name" --profile "$aws_cli_profile" --no-cli-pager | jq -r '.Role.PermissionsBoundary.PermissionsBoundaryArn // empty')
		if [[ "$deployed_boundary_arn" == "$boundary_arn" ]]; then
			printf '\033[0;33m%s\033[0m\n' "WARNING: Role $role_name already uses $boundary_name. Skipping attachment ..."
		else
			aws iam put-role-permissions-boundary \
				--role-name "$role_name" \
				--permissions-boundary "$boundary_arn" \
				--profile "$aws_cli_profile" \
				--no-cli-pager
			printf '\033[0;32m%s\033[0m\n' "Attached $boundary_name to role $role_name."
		fi
	else
		printf '\033[0;33m%s\033[0m\n' "WARNING: Role $role_name does not exist yet. Terraform must create it with this boundary."
	fi
done

# Deploy policies from policies/ directory
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
