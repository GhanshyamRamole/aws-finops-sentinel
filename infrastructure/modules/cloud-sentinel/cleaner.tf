
	# resources cleaner on schedule time

data "archive_file" "cleaner_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src"
  output_path = "${path.module}/cleaner_payload.zip"
}

# --- Shared Schedule (10 AM Daily) ---
resource "aws_cloudwatch_event_rule" "daily_cleanup" {
  name                = "${var.project_name}-Daily-Cleanup"
  schedule_expression = "cron(0 10 * * ? *)"
}

# ---  EBS Cleaner ---
resource "aws_lambda_function" "ebs_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EBS-Cleaner-${var.environment}"
  role             = var.role_arn
  handler          = "cleaners/ebs_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = var.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_ebs" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "TriggerEBS"
  arn       = aws_lambda_function.ebs_cleaner.arn
}

resource "aws_lambda_permission" "allow_ebs" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup.arn
}

# ---  Elastic IP Cleaner ---
resource "aws_lambda_function" "eip_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EIP-Cleaner-${var.environment}"
  role             = var.role_arn
  handler          = "cleaners/eip_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = var.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_eip" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "TriggerEIP"
  arn       = aws_lambda_function.eip_cleaner.arn
}

resource "aws_lambda_permission" "allow_eip" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eip_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup.arn
}

# ---  EC2 Idle Cleaner ---
resource "aws_lambda_function" "ec2_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EC2-Cleaner-${var.environment}"
  role             = var.role_arn
  handler          = "cleaners/ec2_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = var.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_ec2" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "TriggerEC2"
  arn       = aws_lambda_function.ec2_cleaner.arn
}

resource "aws_lambda_permission" "allow_ec2" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup.arn
}
