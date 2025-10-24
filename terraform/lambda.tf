#########################################
# Lambda IAM Role
#########################################

resource "aws_iam_role" "asg_lambda_exec" {
  name = "${var.stage}-asg-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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

  tags = {
    Name = "${var.stage}-asg-lambda-exec-role"
  }
}

#########################################
# Attach Basic Lambda Logging Policy
#########################################

resource "aws_iam_role_policy_attachment" "asg_lambda_basic" {
  role       = aws_iam_role.asg_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#########################################
# Custom Policy for Auto Scaling + CW Access
# Read from /policy/asg_lambda_policy.json
#########################################

resource "aws_iam_role_policy" "asg_lambda_custom" {
  name   = "${var.stage}-asg-lambda-policy"
  role   = aws_iam_role.asg_lambda_exec.id
  policy = file("${path.module}/../policy/asg_lambda_policy.json")
}

#########################################
# Lambda Function
#########################################

resource "aws_lambda_function" "asg_logs_function" {
  function_name = "${var.stage}-asg-logs-handler"
  role          = aws_iam_role.asg_lambda_exec.arn
  handler       = "asg_logs_handler.handler"
  runtime       = "nodejs18.x"

  filename         = "${path.module}/../lambda/asg_logs_handler.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/asg_logs_handler.zip")

  environment {
    variables = {
      REGION = var.region
    }
  }

  tags = {
    Name = "${var.stage}-asg-logs-handler"
  }
}

#########################################
# API Gateway (HTTP API)
#########################################

resource "aws_apigatewayv2_api" "asg_api" {
  name          = "${var.stage}-asg-api"
  protocol_type = "HTTP"
}

#########################################
# Lambda Integration
#########################################

resource "aws_apigatewayv2_integration" "asg_integration" {
  api_id                 = aws_apigatewayv2_api.asg_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.asg_logs_function.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

#########################################
# API Route
#########################################

resource "aws_apigatewayv2_route" "asg_route" {
  api_id    = aws_apigatewayv2_api.asg_api.id
  route_key = "GET /scaling-logs"
  target    = "integrations/${aws_apigatewayv2_integration.asg_integration.id}"
}

#########################################
# Stage (Deployment)
#########################################

resource "aws_apigatewayv2_stage" "asg_stage" {
  api_id      = aws_apigatewayv2_api.asg_api.id
  name        = "$default"
  auto_deploy = true
}

#########################################
# Allow API Gateway to Invoke Lambda
#########################################

resource "aws_lambda_permission" "asg_invoke_permission" {
  statement_id  = "AllowInvokeFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asg_logs_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.asg_api.execution_arn}/*/*"
}

