
	# resources cleaner on schedule time

data "archive_file" "cleaner_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src"
  output_path = "${path.module}/cleaner_payload.zip"
}

# --- Shared Schedule (10 AM Daily) ---
resource "aws_cloudwatch_event_rule" "daily_cleanup" {
  name                = "${var.project_name}-Daily-Cleanup-${var.environment}"
  schedule_expression = "cron(0 10 * * ? *)"
}

# --- 1. EBS Cleaner ---
resource "aws_lambda_function" "ebs_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EBS-Cleaner-${var.environment}"
  
  # FIX: Direct reference to security.tf
  role             = aws_iam_role.lambda_role.arn
  
  handler          = "cleaners/ebs_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  
  environment { 
    # FIX: Direct reference to main.tf
    variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } 
  }
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

# --- 2. Elastic IP Cleaner ---
resource "aws_lambda_function" "eip_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EIP-Cleaner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn  # <--- Direct Reference
  handler          = "cleaners/eip_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  
  environment { 
    variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } 
  }
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

# --- 3. EC2 Idle Cleaner ---
resource "aws_lambda_function" "ec2_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-EC2-Cleaner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn  # <--- Direct Reference
  handler          = "cleaners/ec2_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  
  environment { 
    variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } 
  }
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


# --- 4. Snapshot Cleaner ---
resource "aws_lambda_function" "snapshot_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-Snapshot-Cleaner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "cleaners/snapshot_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } }
}

resource "aws_cloudwatch_event_target" "trigger_snapshot_cl" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "TriggerSnapshotClean"
  arn       = aws_lambda_function.snapshot_cleaner.arn
}

resource "aws_lambda_permission" "allow_snapshot_cl" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup.arn
}

# --- 5. Log Retention Cleaner ---
resource "aws_lambda_function" "log_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-Log-Cleaner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "cleaners/log_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } }
}

resource "aws_cloudwatch_event_target" "trigger_log_cl" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "TriggerLogClean"
  arn       = aws_lambda_function.log_cleaner.arn
}

resource "aws_lambda_permission" "allow_log_cl" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup.arn
}

# --- 6. Load Balancer Cleaner ---
resource "aws_lambda_function" "lb_cleaner" {
  filename         = data.archive_file.cleaner_zip.output_path
  function_name    = "${var.project_name}-LB-Cleaner-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "cleaners/lb_deleter.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleaner_zip.output_base64sha256
  environment { variables = { DYNAMODB_TABLE = aws_dynamodb_table.this.name } }
}

resource "aws_cloudwatch_event_target" "trigger_lb_cl" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "TriggerLBClean"
  arn       = aws_lambda_function.lb_cleaner.arn
}

resource "aws_lambda_permission" "allow_lb_cl" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lb_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_cleanup.arn
}
