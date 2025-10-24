##############################################
# Auto Scaling → SNS → Lambda → CloudWatch Logs
##############################################

# SNS Topic to capture ASG notifications
resource "aws_sns_topic" "asg_notifications" {
  name = "${var.stage}-asg-notifications"
}

# Connect Auto Scaling events to SNS topic
resource "aws_autoscaling_notification" "asg_notification" {
  group_names = [aws_autoscaling_group.devops_asg.name]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]

  topic_arn = aws_sns_topic.asg_notifications.arn
}

# IAM role for Lambda
resource "aws_iam_role" "asg_logger_role" {
  name = "${var.stage}-asg-logger-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Policy for Lambda to write logs
resource "aws_iam_role_policy" "asg_logger_policy" {
  role = aws_iam_role.asg_logger_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Lambda Function to write ASG events to CloudWatch Logs
resource "aws_lambda_function" "asg_to_cloudwatch_logger" {
  function_name = "${var.stage}-asg-log-writer"
  role          = aws_iam_role.asg_logger_role.arn
  runtime       = "nodejs18.x"
  handler       = "index.handler"

  filename = "${path.module}/../lambda/asg_log_writer.zip"

  environment {
    variables = {
      LOG_GROUP = "/aws/autoscaling/${var.stage}-asg"
    }
  }
}

# SNS → Lambda Subscription
resource "aws_sns_topic_subscription" "asg_lambda_subscription" {
  topic_arn = aws_sns_topic.asg_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.asg_to_cloudwatch_logger.arn
}

# Allow SNS to invoke Lambda
resource "aws_lambda_permission" "sns_invoke_lambda" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asg_to_cloudwatch_logger.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.asg_notifications.arn
}
