terraform {
  backend "s3" {
    bucket         = "fintech-platform-tfstate-051826742726-eu-central-1"
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "fintech-platform-tflock-051826742726-eu-central-1"
    encrypt        = true
  }
}
