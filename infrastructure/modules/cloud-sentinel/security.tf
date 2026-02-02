
	# IAM Roles for lambda permission

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-Role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "permissions" {
  name = "${var.project_name}-Permissions-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = ["ec2:Describe*", "ec2:DeleteVolume", "ec2:ReleaseAddress"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["dynamodb:*"],
        Resource = aws_dynamodb_table.this.arn
      },
      {
        Effect = "Allow",
        Action = ["ssm:GetParameter"],
        Resource = aws_ssm_parameter.slack_webhook.arn
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
