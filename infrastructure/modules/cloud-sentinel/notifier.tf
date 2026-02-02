
	# notify user before deleting any resources

data "archive_file" "notifier_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src"
  output_path = "${path.module}/notifier_payload.zip"
}

# --- Schedule: 9:00 AM (Between Scan and Clean) ---
resource "aws_cloudwatch_event_rule" "daily_report" {
  name                = "${var.project_name}-Daily-Report-${var.environment}"
  schedule_expression = "cron(0 9 * * ? *)"
}

resource "aws_lambda_function" "notifier" {
  filename         = data.archive_file.notifier_zip.output_path
  function_name    = "${var.project_name}-Notifier-${var.environment}"
  
  # FIX: Direct Reference to security.tf
  role             = aws_iam_role.lambda_role.arn
  
  handler          = "common/slack_notifier.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.notifier_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      
      DYNAMODB_TABLE    = aws_dynamodb_table.this.name
      SLACK_WEBHOOK_URL = aws_ssm_parameter.slack_webhook.value
    }
  }
}

resource "aws_cloudwatch_event_target" "trigger_notifier" {
  rule      = aws_cloudwatch_event_rule.daily_report.name
  target_id = "TriggerNotifier"
  arn       = aws_lambda_function.notifier.arn
}

resource "aws_lambda_permission" "allow_notifier" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_report.arn
}
