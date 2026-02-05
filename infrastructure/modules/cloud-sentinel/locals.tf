locals {
  # 1. Resource Shortcuts
  # These grab the IDs from the resources created in main.tf and security.tf
  role_arn   = aws_iam_role.lambda_role.arn
  table_name = aws_dynamodb_table.this.name

  # 2. Centralized Schedules
  # Change these here, and it updates all scanners/cleaners automatically
  scan_schedule    = "cron(0 8 * * ? *)"   # 8:00 AM UTC
  report_schedule  = "cron(0 9 * * ? *)"   # 9:00 AM UTC
  cleanup_schedule = "cron(0 10 * * ? *)"  # 10:00 AM UTC
}
