data "archive_file" "cleaner_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src"
  output_path = "${path.module}/cleaner_payload.zip"
}

# ------------------------------------------------------------------------------
# RULES (Split to avoid the 5-target limit)
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "daily_cleanup_batch_1" {
  name                = "${var.project_name}-Daily-Clean-B1-${var.environment}"
  schedule_expression = local.cleanup_schedule
}

resource "aws_cloudwatch_event_rule" "daily_cleanup_batch_2" {
  name                = "${var.project_name}-Daily-Clean-B2-${var.environment}"
  schedule_expression = local.cleanup_schedule
}

# ------------------------------------------------------------------------------
# BATCH 1 CLEANERS (Targets 1-3)
# ------------------------------------------------------------------------------

# 1. EBS Cleaner
resource "aws_lambda_function" "ebs_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EBS-Cleaner-${var.environment}"
  role             = local.role_arn
  handler          = "cleaners/ebs_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_ebs" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup_batch_1.name # <--- BATCH 1
  target_id = "TriggerEBS"
  arn       = aws_lambda_function.ebs_cleaner.arn
}

resource "aws_lambda_permission" "allow_ebs" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup_batch_1.arn
}

# 2. EIP Cleaner
resource "aws_lambda_function" "eip_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EIP-Cleaner-${var.environment}"
  role             = local.role_arn
  handler          = "cleaners/eip_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_eip" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup_batch_1.name # <--- BATCH 1
  target_id = "TriggerEIP"
  arn       = aws_lambda_function.eip_cleaner.arn
}

resource "aws_lambda_permission" "allow_eip" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eip_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup_batch_1.arn
}

# 3. EC2 Cleaner
resource "aws_lambda_function" "ec2_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EC2-Cleaner-${var.environment}"
  role             = local.role_arn
  handler          = "cleaners/ec2_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_ec2" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup_batch_1.name # <--- BATCH 1
  target_id = "TriggerEC2"
  arn       = aws_lambda_function.ec2_cleaner.arn
}

resource "aws_lambda_permission" "allow_ec2" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup_batch_1.arn
}

# ------------------------------------------------------------------------------
# BATCH 2 CLEANERS (Targets 4-6)
# ------------------------------------------------------------------------------

# 4. Snapshot Cleaner
resource "aws_lambda_function" "snapshot_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-Snapshot-Cleaner-${var.environment}"
  role             = local.role_arn
  handler          = "cleaners/snapshot_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_snapshot_cl" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup_batch_2.name # <--- BATCH 2
  target_id = "TriggerSnapshotClean"
  arn       = aws_lambda_function.snapshot_cleaner.arn
}

resource "aws_lambda_permission" "allow_snapshot_cl" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup_batch_2.arn
}

# 5. Log Cleaner
resource "aws_lambda_function" "log_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-Log-Cleaner-${var.environment}"
  role             = local.role_arn
  handler          = "cleaners/log_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_log_cl" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup_batch_2.name # <--- BATCH 2
  target_id = "TriggerLogClean"
  arn       = aws_lambda_function.log_cleaner.arn
}

resource "aws_lambda_permission" "allow_log_cl" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup_batch_2.arn
}

# 6. LB Cleaner
resource "aws_lambda_function" "lb_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-LB-Cleaner-${var.environment}"
  role             = local.role_arn
  handler          = "cleaners/lb_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = local.table_name } }
}

resource "aws_cloudwatch_event_target" "trigger_lb_cl" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup_batch_2.name # <--- BATCH 2
  target_id = "TriggerLBClean"
  arn       = aws_lambda_function.lb_cleaner.arn
}

resource "aws_lambda_permission" "allow_lb_cl" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lb_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup_batch_2.arn
}
