output "cognito_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.this.id
}

output "cognito_url" {
  value = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "lambda_dynamo_invoke_url" {
  value = module.lambda_dynamodb.invoke_arn
}

# output "api_url" {
#   value = aws_api_gateway_deployment.this.invoke_url
# }

output "api_custom_domain_url" {
  value = local.has_domain_name ? "https://${aws_api_gateway_domain_name.this[0].domain_name}" : ""
}

output "tf_dev_role_arn" {
  value = aws_iam_role.terraform_dev.arn
}

output "tf_prod_role_arn" {
  value = aws_iam_role.terraform_prod.arn
}
