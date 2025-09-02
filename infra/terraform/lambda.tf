# --------------- LAMBDA CODE --------------------
resource "terraform_data" "build" {
  triggers_replace = {
    code_hash = local.code_hash
  }

  provisioner "local-exec" {
    command     = "npm run build"
    working_dir = "${path.module}/../../"
  }
}

resource "random_uuid" "build_id" {
  keepers = {
    code_hash = local.code_hash
  }
}

data "archive_file" "codebase" {
  depends_on = [terraform_data.build]

  type        = "zip"
  source_dir  = "${path.module}/../../dist"
  output_path = "files/${random_uuid.build_id.result}.zip"
}

# --------------- LAMBDA INFRA --------------------

module "lambda_dynamodb" {
  source = "./modules/lambda"

  name            = "${local.namespaced_service_name}-dynamodb"
  description     = "Triggered by API Gateway to save data into DynamoDB table"
  handler         = "${local.lambdas_path}/dynamodb.handler"
  iam_role_arn    = module.iam_role_dynamodb_lambda.iam_role_arn
  timeout_in_secs = 15
  memory_in_mb    = 256
  code_hash       = data.archive_file.codebase.output_base64sha256

  s3_config = {
    bucket = aws_s3_bucket.lambda_artefacts.bucket
    key    = aws_s3_object.lambda_artefact.key
  }

  env_vars = {
    JWT_SECRET   = aws_cognito_user_pool_client.this.id
    TABLE_NAME   = aws_dynamodb_table.this.name
    GSI_NAME     = local.dynamodb_config.gsi_name
    DEBUG        = var.environment == "dev"
    CORS_HEADERS = local.formatted_cors.headers
    CORS_METHODS = local.formatted_cors.methods
    CORS_ORIGINS = local.formatted_cors.origins
    CORS_CREDS   = local.formatted_cors.credentials

    AWS_NODEJS_CONNECTION_REUSE_ENABLED = 1
  }
}

module "lambda_third_party" {
  source = "./modules/lambda"

  name            = "${local.namespaced_service_name}-third-party"
  description     = "Handles third-party service integration with Cognito authentication"
  handler         = "${local.lambdas_path}/third-party.handler"
  iam_role_arn    = module.iam_role_third_party_lambda.iam_role_arn
  timeout_in_secs = 30
  memory_in_mb    = 512
  code_hash       = data.archive_file.codebase.output_base64sha256

  s3_config = {
    bucket = aws_s3_bucket.lambda_artefacts.bucket
    key    = aws_s3_object.lambda_artefact.key
  }

  env_vars = {
    USERS_TABLE_NAME     = aws_dynamodb_table.users.name
    COGNITO_USER_POOL_ID = aws_cognito_user_pool.this.id
    AWS_REGION           = var.aws_region
    DEBUG                = var.environment == "dev"
    CORS_HEADERS         = local.formatted_cors.headers
    CORS_METHODS         = local.formatted_cors.methods
    CORS_ORIGINS         = local.formatted_cors.origins
    CORS_CREDS           = local.formatted_cors.credentials

    AWS_NODEJS_CONNECTION_REUSE_ENABLED = 1
  }
}

module "lambda_user_management" {
  source = "./modules/lambda"

  name            = "${local.namespaced_service_name}-user-management"
  description     = "Handles user management operations with Cognito authentication"
  handler         = "${local.lambdas_path}/user-management.handler"
  iam_role_arn    = module.iam_role_user_management_lambda.iam_role_arn
  timeout_in_secs = 15
  memory_in_mb    = 256
  code_hash       = data.archive_file.codebase.output_base64sha256

  s3_config = {
    bucket = aws_s3_bucket.lambda_artefacts.bucket
    key    = aws_s3_object.lambda_artefact.key
  }

  env_vars = {
    USERS_TABLE_NAME     = aws_dynamodb_table.users.name
    COGNITO_USER_POOL_ID = aws_cognito_user_pool.this.id
    AWS_REGION           = var.aws_region
    DEBUG                = var.environment == "dev"
    CORS_HEADERS         = local.formatted_cors.headers
    CORS_METHODS         = local.formatted_cors.methods
    CORS_ORIGINS         = local.formatted_cors.origins
    CORS_CREDS           = local.formatted_cors.credentials

    AWS_NODEJS_CONNECTION_REUSE_ENABLED = 1
  }
}

# --------------- LAMBDA TRIGGERS --------------------

resource "aws_lambda_permission" "apigw_dynamodb" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_dynamodb.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*"
}

resource "aws_lambda_permission" "apigw_third_party" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_third_party.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*"
}

resource "aws_lambda_permission" "apigw_user_management" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_user_management.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*"
}
