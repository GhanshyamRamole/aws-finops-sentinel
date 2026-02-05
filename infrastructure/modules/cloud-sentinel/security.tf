	# IAM Roles for lambda permission

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-Role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}


resource "aws_iam_policy" "lambda_finops_policy" {
  name        = "FinOpsSentinelLeastPrivilege"
  description = "Restricts Lambda to specific project resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DeleteVolume"
        ]
        Effect   = "Allow"
        Resource = "*" # Describe usually requires *
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Effect   = "Allow"
        # Fixed: Restrict to your specific table
        Resource = aws_dynamodb_table.finops_state.arn 
      }
    ]
  })
}
