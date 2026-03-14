terraform {
  backend "s3" {
    bucket       = "tf-state-brodatzkinet-891920435804"
    key          = "aws/secret_store/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}