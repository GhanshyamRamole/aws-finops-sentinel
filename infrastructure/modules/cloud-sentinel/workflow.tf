# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "${var.project_name}-StepFunction-Role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.project_name}-StepFunction-Policy-${var.environment}"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.ebs_scanner.arn,
          aws_lambda_function.eip_scanner.arn,
          aws_lambda_function.ec2_scanner.arn,
          aws_lambda_function.snapshot_scanner.arn,
          aws_lambda_function.log_scanner.arn,
          aws_lambda_function.lb_scanner.arn,
          aws_lambda_function.notifier.arn
        ]
      }
    ]
  })
}

# The State Machine Definition
resource "aws_sfn_state_machine" "finops_workflow" {
  name     = "${var.project_name}-Workflow-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "Run Scanners in parallel, then Notify"
    StartAt = "RunAllScanners"
    States = {
      RunAllScanners = {
        Type = "Parallel"
        Next = "RunNotifier"
        Branches = [
          { StartAt = "ScanEBS", States = { ScanEBS = { Type = "Task", Resource = aws_lambda_function.ebs_scanner.arn, End = true } } },
          { StartAt = "ScanEIP", States = { ScanEIP = { Type = "Task", Resource = aws_lambda_function.eip_scanner.arn, End = true } } },
          { StartAt = "ScanEC2", States = { ScanEC2 = { Type = "Task", Resource = aws_lambda_function.ec2_scanner.arn, End = true } } },
          { StartAt = "ScanSnap", States = { ScanSnap = { Type = "Task", Resource = aws_lambda_function.snapshot_scanner.arn, End = true } } },
          { StartAt = "ScanLogs", States = { ScanLogs = { Type = "Task", Resource = aws_lambda_function.log_scanner.arn, End = true } } },
          { StartAt = "ScanLB",   States = { ScanLB   = { Type = "Task", Resource = aws_lambda_function.lb_scanner.arn, End = true } } }
        ]
      },
      RunNotifier = {
        Type = "Task",
        Resource = aws_lambda_function.notifier.arn
        End = true
      }
    }
  })
}

# Schedule the Workflow (Replaces the individual Scanner rules)
resource "aws_cloudwatch_event_rule" "workflow_trigger" {
  name                = "${var.project_name}-Daily-Workflow-${var.environment}"
  schedule_expression = local.scan_schedule
}

resource "aws_cloudwatch_event_target" "trigger_workflow" {
  rule      = aws_cloudwatch_event_rule.workflow_trigger.name
  target_id = "TriggerStepFunction"
  arn       = aws_sfn_state_machine.finops_workflow.arn
  role_arn  = aws_iam_role.event_bridge_role.arn
}

# EventBridge needs a role to invoke Step Functions
resource "aws_iam_role" "event_bridge_role" {
  name = "${var.project_name}-EventBridge-Role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "events.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "event_bridge_policy" {
  name = "${var.project_name}-EventBridge-Policy-${var.environment}"
  role = aws_iam_role.event_bridge_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "states:StartExecution", Resource = aws_sfn_state_machine.finops_workflow.arn }]
  })
}
