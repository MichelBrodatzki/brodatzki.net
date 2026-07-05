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
        "system:serviceaccount:openwebui:openwebui-cnpg-backup-sa"
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