variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "instance_type_controller" {
  type    = string
  default = "t3.medium"
}

variable "instance_type_agent" {
  type    = string
  default = "t3.medium"
}

variable "allowed_admin_cidr" {
  type        = string
  description = "Only used if we later expose Jenkins behind ALB/VPN. For now SSM is used."
  default     = "0.0.0.0/32"
}
