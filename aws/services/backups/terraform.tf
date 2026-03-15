terraform {
  backend "s3" {
    bucket       = "tf-state-brodatzkinet-891920435804"
    key          = "aws/backups/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}