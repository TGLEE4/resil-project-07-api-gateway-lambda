output "api_url" {
  description = "Public API Gateway URL for the hello route"
  value       = "${aws_apigatewayv2_api.hello_api.api_endpoint}/hello"
}