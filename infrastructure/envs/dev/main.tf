module "cloud_sentinel" {
  source = "../../modules/cloud-sentinel"

  project_name      = var.project_name
  environment       = var.environment
  slack_webhook_url = var.slack_webhook_url
}
