
	#  

resource "aws_lambda_function" "notifier" {
  filename         = data.archive_file.scanner_zip.output_path 
  function_name    = "${var.project_name}-Notifier-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "common/slack_notifier.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE    = aws_dynamodb_table.this.name
      SLACK_WEBHOOK_URL = aws_ssm_parameter.slack_webhook.value
    }
  }
}

resource "aws_cloudwatch_event_rule" "morning_report" {
  name                = "${var.project_name}-MorningReport-${var.environment}"
  schedule_expression = "cron(0 9 * * ? *)"
}

resource "aws_cloudwatch_event_target" "notify_target" {
  rule = aws_cloudwatch_event_rule.morning_report.name
  arn  = aws_lambda_function.notifier.arn
}

resource "aws_lambda_permission" "allow_notify_trigger" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.morning_report.arn
}
