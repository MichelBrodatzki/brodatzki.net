data "aws_caller_identity" "current" {}

# Created by greenfield/02_oidc_provider
data "aws_iam_openid_connect_provider" "ka1_oidc" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/raw.githubusercontent.com/MichelBrodatzki/brodatzki.net/main/.static/ka1"
}

data "aws_iam_policy_document" "ka1_oidc_workload_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.ka1_oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.ka1_oidc.url}:sub"
      values = [
        "system:serviceaccount:longhorn-system:longhorn-secrets-sa",
        "system:serviceaccount:mosquitto:mosquitto-secrets-sa",
        "system:serviceaccount:cert-manager:cert-manager-secrets-sa",
        "system:serviceaccount:n8n:n8n-secrets-sa",
        "system:serviceaccount:plex:plex-secrets-sa",
        "system:serviceaccount:wealthfolio:wealthfolio-secrets-sa",
        "system:serviceaccount:actualbudget:actualbudget-secrets-sa",
        "system:serviceaccount:openwebui:openwebui-secrets-sa",
        "system:serviceaccount:mealie:mealie-secrets-sa",
        "system:serviceaccount:vikunja:vikunja-secrets-sa",
      ]
    }
  }
}

resource "aws_iam_role" "ka1_workload" {
  name                 = "ka1-k8s-secrets-readonly"
  assume_role_policy   = data.aws_iam_policy_document.ka1_oidc_workload_assume_role.json
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/terraform-boundary-ka1-k8s-secrets-readonly"
}

data "aws_iam_policy_document" "ka1_workload_ssm" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:eu-central-1:${data.aws_caller_identity.current.account_id}:parameter/ka1/*"
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:eu-central-1:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_role_policy" "ka1_workload_ssm" {
  name   = "ka1-parameters-readonly-access"
  role   = aws_iam_role.ka1_workload.id
  policy = data.aws_iam_policy_document.ka1_workload_ssm.json
}
