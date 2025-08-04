variable "name" {
  description = "The name of your ECR repository"
  type        = string
}

variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "tags" {
  description = "Tags to set on the repository"
  type        = map(string)
  default     = {}
}