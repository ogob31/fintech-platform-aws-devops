variable "name" {
  type        = string
  description = "Prefix/name for WAF resources"
}

variable "alb_arn" {
  type        = string
  description = "ALB ARN to associate WAF with"
}
