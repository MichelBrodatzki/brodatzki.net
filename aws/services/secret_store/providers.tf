provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      project     = "secret_store"
      environment = "prod"
    }
  }
}