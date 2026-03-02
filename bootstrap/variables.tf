variable "aws_region" {
  description = "AWS region where bootstrap resources (S3 backend and DynamoDB lock table) will be created"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project identifier used for naming Terraform state bucket and DynamoDB lock table"
  type        = string
  default     = "fintech-platform"
}