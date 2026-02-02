variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment dev and prod"
  type        = string
}

variable "slack_webhook_url" {
  description = "The actual URL for Slack notifications"
  type        = string
  sensitive   = true 
}


