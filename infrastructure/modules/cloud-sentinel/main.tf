
	# Handles the Dynamodb database

resource "aws_dynamodb_table" "this" {
  name           = "${var.project_name}-State-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ResourceId"

  attribute {
    name = "ResourceId"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiryTimestamp"
    enabled        = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


resource "aws_ssm_parameter" "slack_webhook" {
  name  = "/${var.project_name}/${var.environment}/slack-webhook-url"
  type  = "SecureString"
  value = var.slack_webhook_url
}
