###############################################################
# 1. IAM Role for Lambda
###############################################################
resource "aws_iam_role" "lambda_asg_role" {
  name = "${var.stage}-lambda-asg-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

###############################################################
# 2. Attach Lambda Permissions (Auto Scaling + CloudWatch)
###############################################################
resource "aws_iam_role_policy" "lambda_asg_policy" {
  name = "${var.stage}-lambda-asg-policy"
  role = aws_iam_role.lambda_asg_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribePolicies",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ],
        Resource = "*"
      },
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

###############################################################
# 3. Lambda Function
###############################################################
resource "aws_lambda_function" "asg_logs_function" {
  function_name = "${var.stage}-asg-logs-handler"
  role          = aws_iam_role.lambda_asg_role.arn
  handler       = "asg_logs_handler.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  filename         = "${path.module}/../lambda/asg_logs_handler.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/asg_logs_handler.zip")
}

###############################################################
# 4. API Gateway for Lambda
###############################################################
resource "aws_apigatewayv2_api" "asg_api" {
  name          = "${var.stage}-asg-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "asg_integration" {
  api_id           = aws_apigatewayv2_api.asg_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.asg_logs_function.invoke_arn
}

resource "aws_apigatewayv2_route" "asg_route" {
  api_id    = aws_apigatewayv2_api.asg_api.id
  route_key = "GET /scaling-logs"
  target    = "integrations/${aws_apigatewayv2_integration.asg_integration.id}"
}

resource "aws_lambda_permission" "asg_api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asg_logs_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.asg_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "asg_stage" {
  api_id      = aws_apigatewayv2_api.asg_api.id
  name        = "$default"
  auto_deploy = true
}

###############################################################
# OUTPUT
###############################################################
output "asg_api_url" {
  value = "${aws_apigatewayv2_api.asg_api.api_endpoint}/scaling-logs"
}
