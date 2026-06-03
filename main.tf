terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

data "aws_lambda_function" "hello" {
  function_name = "resil-hello-lambda"
}

resource "aws_apigatewayv2_api" "hello_api" {
  name          = "resil-project-07-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "hello_lambda" {
  api_id                 = aws_apigatewayv2_api.hello_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.hello.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "hello_route" {
  api_id    = aws_apigatewayv2_api.hello_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.hello_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromProject07APIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.hello.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_api.execution_arn}/*/*"
}