data "aws_caller_identity" "current" {}

data "tls_certificate" "ka1_oidc" {
  url = "https://raw.githubusercontent.com/MichelBrodatzki/brodatzki.net/main/.static/ka1/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "ka1_oidc" {
  url             = "https://raw.githubusercontent.com/MichelBrodatzki/brodatzki.net/main/.static/ka1"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.ka1_oidc.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "ka1_oidc_workload_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ka1_oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${aws_iam_openid_connect_provider.ka1_oidc.url}:sub"
      values = [
        "system:serviceaccount:mosquitto:mosquitto-sa",
        "system:serviceaccount:cert-manager:cert-manager-secrets-sa"
      ]
    }
  }
}

resource "aws_iam_role" "ka1_workload" {
  name               = "ka1-k8s-secrets-readonly"
  assume_role_policy = data.aws_iam_policy_document.ka1_oidc_workload_assume_role.json
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
    effect = "Allow"
    actions = ["kms:Decrypt"]
    resources = ["arn:aws:kms:eu-central-1:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_policy" "ka1_workload_ssm" {
  name   = "ka1-parameters-readonly-access"
  policy = data.aws_iam_policy_document.ka1_workload_ssm.json
}

resource "aws_iam_role_policy_attachment" "ka1_workload_ssm" {
  role       = aws_iam_role.ka1_workload.name
  policy_arn = aws_iam_policy.ka1_workload_ssm.arn
}