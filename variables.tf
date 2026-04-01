variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "event-driven-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
}