
	# 

resource "aws_lambda_function" "cleaner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-Cleaner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "cleaners/resource_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  timeout          = 60

  environment {
    variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name }
  }
}

resource "aws_cloudwatch_event_rule" "cleanup_job" {
  name                = "${var.project_name}-Cleanup-${var.environment}"
  schedule_expression = "cron(0 10 * * ? *)"
}

resource "aws_cloudwatch_event_target" "clean_target" {
  rule = aws_cloudwatch_event_rule.cleanup_job.name
  arn  = aws_lambda_function.cleaner.arn
}

resource "aws_lambda_permission" "allow_clean_trigger" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_job.arn
}
