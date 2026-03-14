#!/usr/bin/env zsh
set -euo pipefail

# Cleanup temp files on exit
cleanup_files=()
cleanup() { for f in "${cleanup_files[@]}"; do rm -f "$f"; done }
trap cleanup EXIT

printf '\033[0;35m%s\033[0m\n' "This script will configure AWS for usage with terraform. This includes the state bucket as well as all necessary project policies."

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

# Construct tf-state S3 bucket name
aws_account_id=$(aws sts get-caller-identity --query Account --output text --profile "$aws_cli_profile")
tf_state_bucket_name="tf-state-brodatzkinet-$aws_account_id"

# Create S3 bucket
if aws s3api head-bucket --bucket "$tf_state_bucket_name" --profile "$aws_cli_profile" --no-cli-pager >/dev/null 2>&1; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: Skipping S3 bucket creation as bucket $tf_state_bucket_name already exists"
else
	printf '\033[0;32m%s\033[0m\n' "Creating S3 bucket $tf_state_bucket_name ..."
	aws s3api create-bucket --bucket "$tf_state_bucket_name" --region eu-central-1 --create-bucket-configuration "LocationConstraint=eu-central-1" --bucket-namespace "global" --profile "$aws_cli_profile" --no-cli-pager
	aws s3api put-bucket-tagging --bucket "$tf_state_bucket_name" --tagging 'TagSet=[{Key=project,Value=terraform},{Key=environment,Value=prod}]' --profile "$aws_cli_profile"
fi

# Enable S3 Bucket versioning
versioning_status=$(aws s3api get-bucket-versioning --bucket "$tf_state_bucket_name" --profile "$aws_cli_profile" | jq -r '.Status // empty')
if [[ "$versioning_status" == "Enabled" ]]; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: Bucket versioning is already enabled. Skipping enabling ..."
else
	printf '\033[0;32m%s\033[0m\n' "Bucket versioning not enabled. Enabling ..."
	aws s3api put-bucket-versioning --bucket "$tf_state_bucket_name" --versioning-configuration Status=Enabled --profile "$aws_cli_profile"
fi

# Enable S3 Bucket encryption
sse_algorithm=$(aws s3api get-bucket-encryption --bucket "$tf_state_bucket_name" --profile "$aws_cli_profile" 2>/dev/null | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm // empty')
if [[ "$sse_algorithm" == "AES256" ]]; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: Bucket encryption is already enabled. Skipping enabling ..."
else
	printf '\033[0;32m%s\033[0m\n' "Bucket encryption not enabled. Enabling ..."
	aws s3api put-bucket-encryption --bucket "$tf_state_bucket_name" --server-side-encryption-configuration '
	   {
	    "Rules": [{
	      "ApplyServerSideEncryptionByDefault": {
		"SSEAlgorithm": "AES256"
	      }
	    }]
	  }'
fi

# Disable public access to S3 Bucket
access_block_correctly_set=$(aws s3api get-public-access-block --bucket "$tf_state_bucket_name" --profile "$aws_cli_profile" | jq ".PublicAccessBlockConfiguration.BlockPublicAcls and .PublicAccessBlockConfiguration.IgnorePublicAcls and .PublicAccessBlockConfiguration.BlockPublicPolicy and .PublicAccessBlockConfiguration.RestrictPublicBuckets")

if [ "$access_block_correctly_set" = "true" ]; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: Bucket public access is already blocked. Skipping blocking ..."
else
	printf '\033[0;32m%s\033[0m\n' "Bucket public access not enabled. Enabling ..."
	aws s3api put-public-access-block --bucket "$tf_state_bucket_name" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --profile "$aws_cli_profile"
fi

# Create GitHub IdP provider
if aws iam list-open-id-connect-providers --profile "$aws_cli_profile" | jq -e '[.OpenIDConnectProviderList[].Arn] | any(. | endswith("token.actions.githubusercontent.com"))' >/dev/null 2>&1; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: GitHub OIDC provider already exists. Skipping creating ..."
else
	printf '\033[0;32m%s\033[0m\n' "GitHub OIDC provider doesn't exist. Creating ..."
	aws iam create-open-id-connect-provider --url "https://token.actions.githubusercontent.com" --client-id-list "sts.amazonaws.com" --no-cli-pager --profile "$aws_cli_profile"
fi

# Create RW-access role for GitHub Actions to assume
s3_iam_rw_role_exists=$(aws iam list-roles --profile "$aws_cli_profile" | jq '[.Roles[].RoleName] | any(.=="github-actions-terraform-state-readwrite")')

if [ "$s3_iam_rw_role_exists" = "true" ]; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: S3 Bucket GitHub RW-access role already exists. Skipping creating ..."
else
	printf '\033[0;32m%s\033[0m\n' "S3 Bucket RW-access role does not exist."
	printf '\033[0;32m%s\033[0m\n' "Creating assume policy document ..."
	assume_policy_file=$(mktemp)
	cleanup_files+=("$assume_policy_file")
	tee "$assume_policy_file" >/dev/null <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
	{
	    "Effect": "Allow",
	    "Principal": {
		"Federated": "$(aws iam list-open-id-connect-providers --profile "$aws_cli_profile" | jq -r '.OpenIDConnectProviderList[].Arn | select(. | endswith("token.actions.githubusercontent.com"))')"
	    },
	    "Action": "sts:AssumeRoleWithWebIdentity",
	    "Condition": {
		"StringEquals": {
		    "token.actions.githubusercontent.com:sub": "repo:${${$(git remote get-url origin)#git@github.com:}%.git}:ref:refs/heads/main",
		    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
		}
	    }
	}
    ]
}
EOF
	printf '\033[0;32m%s\033[0m\n' "Creating role ..."
	aws iam create-role --role-name github-actions-terraform-state-readwrite --assume-role-policy-document "file://$assume_policy_file" --no-cli-pager --profile "$aws_cli_profile" >/dev/null

	printf '\033[0;32m%s\033[0m\n' "Creating RW access policy ..."
	policy_file=$(mktemp)
	cleanup_files+=("$policy_file")
	tee "$policy_file" >/dev/null <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::$tf_state_bucket_name",
        "arn:aws:s3:::$tf_state_bucket_name/*"
      ]
    }
  ]
}
EOF

	printf '\033[0;32m%s\033[0m\n' "Attaching RW access policy to role ..."
	aws iam put-role-policy --role-name github-actions-terraform-state-readwrite --policy-name terraform-state-readwrite-access --policy-document "file://$policy_file" --profile "$aws_cli_profile" >/dev/null
fi

# Create RO-access role for GitHub Actions to assume
s3_iam_ro_role_exists=$(aws iam list-roles --profile "$aws_cli_profile" | jq '[.Roles[].RoleName] | any(.=="github-actions-terraform-state-readonly")')

if [ "$s3_iam_ro_role_exists" = "true" ]; then
	printf '\033[0;33m%s\033[0m\n' "WARNING: S3 Bucket GitHub RO-access role already exists. Skipping creating ..."
else
	printf '\033[0;32m%s\033[0m\n' "S3 Bucket RO-access role does not exist."
	printf '\033[0;32m%s\033[0m\n' "Creating assume policy document ..."
	assume_policy_file=$(mktemp)
	cleanup_files+=("$assume_policy_file")
	tee "$assume_policy_file" >/dev/null <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
	{
	    "Effect": "Allow",
	    "Principal": {
		"Federated": "$(aws iam list-open-id-connect-providers --profile "$aws_cli_profile" | jq -r '.OpenIDConnectProviderList[].Arn | select(. | endswith("token.actions.githubusercontent.com"))')"
	    },
	    "Action": "sts:AssumeRoleWithWebIdentity",
	    "Condition": {
		"StringEquals": {
		    "token.actions.githubusercontent.com:sub": "repo:${${$(git remote get-url origin)#git@github.com:}%.git}:pull_request",
		    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
		}
	    }
	}
    ]
}
EOF
	printf '\033[0;32m%s\033[0m\n' "Creating role ..."
	aws iam create-role --role-name github-actions-terraform-state-readonly --assume-role-policy-document "file://$assume_policy_file" --no-cli-pager --profile "$aws_cli_profile" >/dev/null

	printf '\033[0;32m%s\033[0m\n' "Creating RO access policy ..."
	policy_file=$(mktemp)
	cleanup_files+=("$policy_file")
	tee "$policy_file" >/dev/null <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::$tf_state_bucket_name",
        "arn:aws:s3:::$tf_state_bucket_name/*"
      ]
    }
  ]
}
EOF

	printf '\033[0;32m%s\033[0m\n' "Attaching RO access policy to role ..."
	aws iam put-role-policy --role-name github-actions-terraform-state-readonly --policy-name terraform-state-readonly-access --policy-document "file://$policy_file" --profile "$aws_cli_profile" >/dev/null
fi
