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
        "system:serviceaccount:openwebui:cluster-openwebui"
      ]
    }
  }
}

resource "aws_iam_role" "ka1_workload" {
  name               = "ka1-k8s-cnpg-backup"
  assume_role_policy = data.aws_iam_policy_document.ka1_oidc_workload_assume_role.json
}

data "aws_iam_policy_document" "ka1_workload_ssm" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.backups.arn}/ka1_brodatzki_network/kube1/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.backups.arn
    ]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "ka1_brodatzki_network/kube1/*"
      ]
    }
  }
}

resource "aws_iam_policy" "ka1_workload_ssm" {
  name   = "ka1-cnpg-backup-access"
  policy = data.aws_iam_policy_document.ka1_workload_ssm.json
}

resource "aws_iam_role_policy_attachment" "ka1_workload_ssm" {
  role       = aws_iam_role.ka1_workload.name
  policy_arn = aws_iam_policy.ka1_workload_ssm.arn
}