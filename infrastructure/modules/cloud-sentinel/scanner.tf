

data "archive_file" "scanner_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src"
  output_path = "${path.module}/scanner_payload.zip"
}

# ------------------------------------------------------------------------------
# RULES (Split to avoid the 5-target limit)
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "daily_scan_batch_1" {
  name                = "${var.project_name}-Daily-Scan-B1-${var.environment}"
  schedule_expression = local.scan_schedule
}

resource "aws_cloudwatch_event_rule" "daily_scan_batch_2" {
  name                = "${var.project_name}-Daily-Scan-B2-${var.environment}"
  schedule_expression = local.scan_schedule
}

# ------------------------------------------------------------------------------
# BATCH 1 SCANNERS (Targets 1-3) -> Linked to Batch 1 Rule
# ------------------------------------------------------------------------------

# 1. EBS Volume Scanner
resource "aws_lambda_function" "ebs_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-EBS-Scanner-${var.environment}"
  role             = local.role_arn
  handler          = "scanners/ebs_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_ebs_scan" {
  rule      = aws_cloudwatch_event_rule.daily_scan_batch_1.name # <--- BATCH 1
  target_id = "TriggerEBSScan"
  arn       = aws_lambda_function.ebs_scanner.arn
}

resource "aws_lambda_permission" "allow_ebs_scan" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan_batch_1.arn
}

# 2. Elastic IP Scanner
resource "aws_lambda_function" "eip_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-EIP-Scanner-${var.environment}"
  role             = local.role_arn
  handler          = "scanners/elastic_ip_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_eip_scan" {
  rule      = aws_cloudwatch_event_rule.daily_scan_batch_1.name # <--- BATCH 1
  target_id = "TriggerEIPScan"
  arn       = aws_lambda_function.eip_scanner.arn
}

resource "aws_lambda_permission" "allow_eip_scan" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eip_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan_batch_1.arn
}

# 3. EC2 Idle Scanner
resource "aws_lambda_function" "ec2_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-EC2-Scanner-${var.environment}"
  role             = local.role_arn
  handler          = "scanners/ec2_idle_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_ec2_scan" {
  rule      = aws_cloudwatch_event_rule.daily_scan_batch_1.name # <--- BATCH 1
  target_id = "TriggerEC2Scan"
  arn       = aws_lambda_function.ec2_scanner.arn
}

resource "aws_lambda_permission" "allow_ec2_scan" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan_batch_1.arn
}

# ------------------------------------------------------------------------------
# BATCH 2 SCANNERS (Targets 4-6) -> Linked to Batch 2 Rule
# ------------------------------------------------------------------------------

# 4. Snapshot Scanner
resource "aws_lambda_function" "snapshot_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-Snapshot-Scanner-${var.environment}"
  role             = local.role_arn
  handler          = "scanners/snapshot_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  timeout          = 60
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_snapshot_scan" {
  rule      = aws_cloudwatch_event_rule.daily_scan_batch_2.name # <--- BATCH 2
  target_id = "TriggerSnapshotScan"
  arn       = aws_lambda_function.snapshot_scanner.arn
}

resource "aws_lambda_permission" "allow_snapshot_scan" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan_batch_2.arn
}

# 5. Log Retention Scanner
resource "aws_lambda_function" "log_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-Log-Scanner-${var.environment}"
  role             = local.role_arn
  handler          = "scanners/log_retention_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_log_scan" {
  rule      = aws_cloudwatch_event_rule.daily_scan_batch_2.name # <--- BATCH 2
  target_id = "TriggerLogScan"
  arn       = aws_lambda_function.log_scanner.arn
}

resource "aws_lambda_permission" "allow_log_scan" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan_batch_2.arn
}

# 6. Orphaned Load Balancer Scanner
resource "aws_lambda_function" "lb_scanner" {
  filename         = data.archive_file.scanner_zip.output_path
  function_name    = "${var.project_name}-LB-Scanner-${var.environment}"
  role             = local.role_arn
  handler          = "scanners/orphaned_lb_scanner.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.scanner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_lb_scan" {
  rule      = aws_cloudwatch_event_rule.daily_scan_batch_2.name # <--- BATCH 2
  target_id = "TriggerLBScan"
  arn       = aws_lambda_function.lb_scanner.arn
}

resource "aws_lambda_permission" "allow_lb_scan" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lb_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan_batch_2.arn
}
