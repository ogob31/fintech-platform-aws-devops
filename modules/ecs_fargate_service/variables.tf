variable "name" { type = string }

variable "vpc_id" { type = string }

variable "public_subnet_ids" { type = list(string) }
variable "private_app_subnet_ids" { type = list(string) }

variable "alb_sg_id" { type = string }
variable "ecs_sg_id" { type = string }

variable "image" { type = string }

variable "container_port" {
  type    = number
  default = 3000
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "db_host" { type = string }
variable "db_port" { type = number }
variable "db_name" { type = string }

variable "ssm_db_username_param" { type = string }
variable "ssm_db_password_param" { type = string }

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener"
}
