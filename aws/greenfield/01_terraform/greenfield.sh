#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")

# Find AWS CLI profile
aws_cli_profiles=("${(@f)$(aws configure list-profiles)}")

if [[ ${#aws_cli_profiles[@]} -eq 1 ]]; then
	printf '\033[0;37m%s\033[0m\n' "Only one AWS CLI profile configured."
	aws_cli_profile="$aws_cli_profiles"
else
	printf '\033[0;33m%s\033[0m\n' "WARNING: Found ${#aws_cli_profiles[@]} AWS CLI profiles."
	select aws_cli_profile in "${aws_cli_profiles[@]}"; do
		[[ -n "$aws_cli_profile" ]] && break
	done
fi

printf '\033[0;32m%s\033[0m\n' "Chose profile $aws_cli_profile for deployment ..."
export AWS_CLI_PROFILE="$aws_cli_profile"

echo "----- [ FOUNDATION ] -----"
$SCRIPT_DIR/foundation.sh

echo "\n\n----- [ POLICIES ] -----"
$SCRIPT_DIR/policies.sh
