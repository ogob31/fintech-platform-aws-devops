variable "name" {
  description = "Prefix for naming resources"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "fintech"
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage in GB"
  type        = number
  default     = 20
}

variable "db_subnet_ids" {
  description = "Private DB subnet IDs"
  type        = list(string)
}

variable "db_sg_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "ssm_username_param" {
  description = "SSM parameter name for DB username"
  type        = string
}

variable "ssm_password_param" {
  description = "SSM parameter name for DB password"
  type        = string
}
