
	# scanner for scanning aws resources {ebs volumes, Elastic IP}

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

# ---  Elastic IP Scanner ---

resource "aws_lambda_function" "eip_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-EIP-Scanner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scanners/elastic_ip_scanner.lambda_handler" # <--- Points to the IP script
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name }
  }
}

# Link existing schedule to the new IP Scanner
resource "aws_cloudwatch_event_target" "eip_scan_target" {
  rule = aws_cloudwatch_event_rule.daily_scan.name
  arn  = aws_lambda_function.eip_scanner.arn
  target_id = "TriggerEIPScanner"
}

# Allow EventBridge to trigger 
resource "aws_lambda_permission" "allow_eip_scan_trigger" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eip_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan.arn
}


# ---  EC2 Idle Scanner ---

resource "aws_lambda_function" "ec2_idle_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-EC2-Idle-Scanner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scanners/ec2_idle_scanner.lambda_handler" # <--- Points to the Idle script
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name }
  }
}

# Link to the Daily Schedule
resource "aws_cloudwatch_event_target" "ec2_idle_target" {
  rule      = aws_cloudwatch_event_rule.daily_scan.name
  arn       = aws_lambda_function.ec2_idle_scanner.arn
  target_id = "TriggerEC2IdleScanner"
}

# Allow EventBridge to trigger
resource "aws_lambda_permission" "allow_ec2_idle_trigger" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_idle_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan.arn
}
