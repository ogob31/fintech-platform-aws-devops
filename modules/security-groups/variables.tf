variable "name" {
  description = "Prefix for security group names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups are created"
  type        = string
}

variable "app_port" {
  description = "Container/app port exposed by the service"
  type        = number
  default     = 3000
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}
