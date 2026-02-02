
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

# --- 4. Snapshot Scanner ---
resource "aws_lambda_function" "snapshot_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-Snapshot-Scanner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scanners/snapshot_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  timeout          = 60 # Snapshots list can be long
  environment { variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } }
}

resource "aws_cloudwatch_event_target" "trigger_snapshot" {
  rule      = aws_cloudwatch_event_rule.daily_scan.name
  target_id = "TriggerSnapshot"
  arn       = aws_lambda_function.snapshot_scanner.arn
}

resource "aws_lambda_permission" "allow_snapshot" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan.arn
}

# --- 5. Log Retention Scanner ---
resource "aws_lambda_function" "log_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-Log-Scanner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scanners/log_retention_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } }
}

resource "aws_cloudwatch_event_target" "trigger_logs" {
  rule      = aws_cloudwatch_event_rule.daily_scan.name
  target_id = "TriggerLogs"
  arn       = aws_lambda_function.log_scanner.arn
}

resource "aws_lambda_permission" "allow_logs" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan.arn
}

# --- 6. Orphaned Load Balancer Scanner ---
resource "aws_lambda_function" "lb_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-LB-Scanner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scanners/orphaned_lb_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } }
}

resource "aws_cloudwatch_event_target" "trigger_lb" {
  rule      = aws_cloudwatch_event_rule.daily_scan.name
  target_id = "TriggerLB"
  arn       = aws_lambda_function.lb_scanner.arn
}

resource "aws_lambda_permission" "allow_lb" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lb_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan.arn
}
