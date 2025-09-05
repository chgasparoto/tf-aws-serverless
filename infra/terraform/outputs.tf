output "cognito_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.this.id
}

output "cognito_url" {
  value = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "api_url" {
  value       = aws_api_gateway_stage.this.invoke_url
  description = "Base API Gateway URL"
}

output "api_v1_url" {
  value       = "${aws_api_gateway_stage.this.invoke_url}/v1"
  description = "API Gateway URL with v1 prefix for all endpoints"
}

output "api_custom_domain_url" {
  value       = local.has_domain_name ? "https://${aws_api_gateway_domain_name.this[0].domain_name}" : ""
  description = "Custom domain API Gateway URL (if configured)"
}

output "api_custom_domain_v1_url" {
  value       = local.has_domain_name ? "https://${aws_api_gateway_domain_name.this[0].domain_name}/v1" : ""
  description = "Custom domain API Gateway URL with v1 prefix (if configured)"
}

output "tf_dev_role_arn" {
  value = var.environment == "dev" ? aws_iam_role.terraform_dev[0].arn : ""
}

output "tf_prod_role_arn" {
  value = var.environment == "dev" ? aws_iam_role.terraform_prod[0].arn : ""
}

# --------------- DYNAMODB OUTPUTS --------------------
output "dynamodb_table_name" {
  value       = aws_dynamodb_table.this.name
  description = "Main DynamoDB table name"
}

output "dynamodb_users_table_name" {
  value       = aws_dynamodb_table.users.name
  description = "Users DynamoDB table name"
}

# --------------- SECRETS MANAGER OUTPUTS --------------------
output "github_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.github_credentials.arn
  description = "GitHub credentials secret ARN"
}

output "slack_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.slack_credentials.arn
  description = "Slack credentials secret ARN"
}

output "jira_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.jira_credentials.arn
  description = "Jira credentials secret ARN"
}

output "third_party_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.third_party_credentials.arn
  description = "Generic third-party credentials secret ARN"
}

# --------------- LAMBDA OUTPUTS --------------------
output "lambda_dynamodb_function_name" {
  value       = module.lambda_dynamodb.name
  description = "DynamoDB Lambda function name"
}

output "lambda_third_party_function_name" {
  value       = module.lambda_third_party.name
  description = "Third-party integration Lambda function name"
}

output "lambda_user_management_function_name" {
  value       = module.lambda_user_management.name
  description = "User management Lambda function name"
}

output "lambda_auth_signup_function_name" {
  value       = module.lambda_auth_signup.name
  description = "Auth signup Lambda function name"
}

# --------------- S3 OUTPUTS --------------------
output "lambda_artifacts_bucket_name" {
  value       = aws_s3_bucket.lambda_artefacts.bucket
  description = "S3 bucket name for Lambda artifacts"
}

# --------------- USEFUL COMBINED OUTPUTS --------------------
output "secrets_manager_secret_names" {
  value = {
    github      = aws_secretsmanager_secret.github_credentials.name
    slack       = aws_secretsmanager_secret.slack_credentials.name
    jira        = aws_secretsmanager_secret.jira_credentials.name
    third_party = aws_secretsmanager_secret.third_party_credentials.name
  }
  description = "All Secrets Manager secret names for easy reference"
}

output "lambda_function_names" {
  value = {
    dynamodb        = module.lambda_dynamodb.name
    third_party     = module.lambda_third_party.name
    user_management = module.lambda_user_management.name
    auth_signup     = module.lambda_auth_signup.name
  }
  description = "All Lambda function names for monitoring and debugging"
}
