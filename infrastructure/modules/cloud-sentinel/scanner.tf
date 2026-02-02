
	# 

data "archive_file" "scanner_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src"
  output_path = "${path.module}/scanner_payload.zip"
}

resource "aws_lambda_function" "scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-Scanner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scanners/ebs_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name }
  }
}

resource "aws_cloudwatch_event_rule" "daily_scan" {
  name                = "${var.project_name}-DailyScan-${var.environment}"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "scan_target" {
  rule = aws_cloudwatch_event_rule.daily_scan.name
  arn  = aws_lambda_function.scanner.arn
}

resource "aws_lambda_permission" "allow_scan_trigger" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan.arn
}
