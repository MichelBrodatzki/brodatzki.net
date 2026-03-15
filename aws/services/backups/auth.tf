locals {
  backup_hosts = [
    "vps1.netcup.brodatzki.network",
  ]

  backup_hosts_map = {
    for host in local.backup_hosts : replace(host, ".", "_") => host
  }
}

resource "aws_rolesanywhere_trust_anchor" "backup" {
  name    = "backup-ca"
  enabled = true
  source {
    source_type = "CERTIFICATE_BUNDLE"
    source_data {
      x509_certificate_data = file("backup_ca.pem")
    }
  }
}

resource "aws_iam_role" "backup" {
  for_each = local.backup_hosts_map

  name = "${replace(each.value, ".", "-")}-backup"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rolesanywhere.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession", "sts:SetSourceIdentity"]
      Condition = {
        StringEquals = {
          "aws:PrincipalTag/x509Subject/CN" = each.value
        }
        ArnEquals = {
          "aws:SourceArn" = aws_rolesanywhere_trust_anchor.backup.arn
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "backup" {
  for_each = local.backup_hosts_map

  role = aws_iam_role.backup[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.backups.arn}/${each.key}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.backups.arn
        Condition = {
          StringLike = { "s3:prefix" = "${each.key}/*" }
        }
      }
    ]
  })
}

resource "aws_rolesanywhere_profile" "backup" {
  name      = "backup"
  role_arns = [for role in aws_iam_role.backup : role.arn]
  enabled   = true
}
