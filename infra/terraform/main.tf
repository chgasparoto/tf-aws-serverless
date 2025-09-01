provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "Project"   = "TF AWS Serverless"
      "CreateAt"  = "2025-09-01"
      "ManagedBy" = "Terraform"
      "Owner"     = "Cleber Gasparoto"
    }
  }
}
