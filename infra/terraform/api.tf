resource "aws_api_gateway_rest_api" "this" {
  name = local.namespaced_service_name

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  name          = "CognitoUserPoolAuthorizer"
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.this.arn]
}

resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "v1"
}

# Todo endpoints
resource "aws_api_gateway_resource" "todos" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "todos"
}

resource "aws_api_gateway_resource" "todo" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.todos.id
  path_part   = "{todoId}"
}

# Auth endpoints
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "signup" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "signup"
}

# User management endpoints
resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "user" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "{userId}"
}

# Third-party service endpoints
resource "aws_api_gateway_resource" "third_party" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "third-party"
}

resource "aws_api_gateway_resource" "third_party_user" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.third_party.id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "third_party_user_resource" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.third_party_user.id
  path_part   = "{userId}"
}

resource "aws_api_gateway_resource" "third_party_resource" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.third_party_user_resource.id
  path_part   = "resource"
}

resource "aws_api_gateway_resource" "third_party_resource_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.third_party_resource.id
  path_part   = "{resourceId}"
}

# GitHub-specific endpoints
resource "aws_api_gateway_resource" "third_party_repos" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.third_party_user_resource.id
  path_part   = "repos"
}

resource "aws_api_gateway_resource" "third_party_repo" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.third_party_repos.id
  path_part   = "{repoName}"
}

# Todo methods
resource "aws_api_gateway_method" "todos" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.todos.id
  authorization = "COGNITO_USER_POOLS"
  http_method   = "ANY"
  authorizer_id = aws_api_gateway_authorizer.this.id
}

resource "aws_api_gateway_method" "todo" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.todo.id
  authorization = "COGNITO_USER_POOLS"
  http_method   = "ANY"
  authorizer_id = aws_api_gateway_authorizer.this.id

  request_parameters = {
    "method.request.path.todoId" = true
  }
}

# Auth methods
resource "aws_api_gateway_method" "signup" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.signup.id
  authorization = "NONE"
  http_method   = "POST"
}

# User management methods
resource "aws_api_gateway_method" "users" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.users.id
  authorization = "NONE"
  http_method   = "POST"
}

resource "aws_api_gateway_method" "user" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.user.id
  authorization = "COGNITO_USER_POOLS"
  http_method   = "ANY"
  authorizer_id = aws_api_gateway_authorizer.this.id

  request_parameters = {
    "method.request.path.userId" = true
  }
}

# Third-party service methods
resource "aws_api_gateway_method" "third_party_resources" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.third_party_resource.id
  authorization = "COGNITO_USER_POOLS"
  http_method   = "ANY"
  authorizer_id = aws_api_gateway_authorizer.this.id

  request_parameters = {
    "method.request.path.userId" = true
  }
}

resource "aws_api_gateway_method" "third_party_resource_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.third_party_resource_id.id
  authorization = "COGNITO_USER_POOLS"
  http_method   = "ANY"
  authorizer_id = aws_api_gateway_authorizer.this.id

  request_parameters = {
    "method.request.path.userId"     = true
    "method.request.path.resourceId" = true
  }
}

# GitHub-specific methods
resource "aws_api_gateway_method" "third_party_repos" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.third_party_repos.id
  authorization = "COGNITO_USER_POOLS"
  http_method   = "ANY"
  authorizer_id = aws_api_gateway_authorizer.this.id

  request_parameters = {
    "method.request.path.userId" = true
  }
}

resource "aws_api_gateway_method" "third_party_repo" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.third_party_repo.id
  authorization = "COGNITO_USER_POOLS"
  http_method   = "ANY"
  authorizer_id = aws_api_gateway_authorizer.this.id

  request_parameters = {
    "method.request.path.userId"   = true
    "method.request.path.repoName" = true
  }
}

# Todo integrations
resource "aws_api_gateway_integration" "todos" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.todos.id
  http_method             = aws_api_gateway_method.todos.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_dynamodb.invoke_arn
}

resource "aws_api_gateway_integration" "todo" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.todo.id
  http_method             = aws_api_gateway_method.todo.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_dynamodb.invoke_arn

  request_parameters = {
    "integration.request.path.todoId" = "method.request.path.todoId"
  }
}

# Auth integrations
resource "aws_api_gateway_integration" "signup" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.signup.id
  http_method             = aws_api_gateway_method.signup.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_auth_signup.invoke_arn
}

# User management integrations
resource "aws_api_gateway_integration" "users" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.users.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_user_management.invoke_arn
}

resource "aws_api_gateway_integration" "user" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.user.id
  http_method             = aws_api_gateway_method.user.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_user_management.invoke_arn

  request_parameters = {
    "integration.request.path.userId" = "method.request.path.userId"
  }
}

# Third-party service integrations
resource "aws_api_gateway_integration" "third_party_resources" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.third_party_resource.id
  http_method             = aws_api_gateway_method.third_party_resources.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_third_party.invoke_arn

  request_parameters = {
    "integration.request.path.userId" = "method.request.path.userId"
  }
}

resource "aws_api_gateway_integration" "third_party_resource_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.third_party_resource_id.id
  http_method             = aws_api_gateway_method.third_party_resource_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_third_party.invoke_arn

  request_parameters = {
    "integration.request.path.userId"     = "method.request.path.userId"
    "integration.request.path.resourceId" = "method.request.path.resourceId"
  }
}

# GitHub-specific integrations
resource "aws_api_gateway_integration" "third_party_repos" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.third_party_repos.id
  http_method             = aws_api_gateway_method.third_party_repos.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_third_party.invoke_arn

  request_parameters = {
    "integration.request.path.userId" = "method.request.path.userId"
  }
}

resource "aws_api_gateway_integration" "third_party_repo" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.third_party_repo.id
  http_method             = aws_api_gateway_method.third_party_repo.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_third_party.invoke_arn

  request_parameters = {
    "integration.request.path.userId"   = "method.request.path.userId"
    "integration.request.path.repoName" = "method.request.path.repoName"
  }
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.todos,
      aws_api_gateway_resource.todo,
      aws_api_gateway_resource.auth,
      aws_api_gateway_resource.signup,
      aws_api_gateway_resource.users,
      aws_api_gateway_resource.user,
      aws_api_gateway_resource.third_party,
      aws_api_gateway_resource.third_party_user,
      aws_api_gateway_resource.third_party_user_resource,
      aws_api_gateway_resource.third_party_resource,
      aws_api_gateway_resource.third_party_resource_id,
      aws_api_gateway_resource.third_party_repos,
      aws_api_gateway_resource.third_party_repo,
      aws_api_gateway_method.todos,
      aws_api_gateway_method.todo,
      aws_api_gateway_method.signup,
      aws_api_gateway_method.users,
      aws_api_gateway_method.user,
      aws_api_gateway_method.third_party_resources,
      aws_api_gateway_method.third_party_resource_by_id,
      aws_api_gateway_method.third_party_repos,
      aws_api_gateway_method.third_party_repo,
      aws_api_gateway_integration.todos,
      aws_api_gateway_integration.todo,
      aws_api_gateway_integration.signup,
      aws_api_gateway_integration.users,
      aws_api_gateway_integration.user,
      aws_api_gateway_integration.third_party_resources,
      aws_api_gateway_integration.third_party_resource_by_id,
      aws_api_gateway_integration.third_party_repos,
      aws_api_gateway_integration.third_party_repo,
      aws_api_gateway_method.cors,
      aws_api_gateway_integration.cors,
      aws_api_gateway_method_response.cors,
      aws_api_gateway_integration_response.cors,
      aws_api_gateway_method.cors_todo,
      aws_api_gateway_integration.cors_todo,
      aws_api_gateway_method_response.cors_todo,
      aws_api_gateway_integration_response.cors_todo,
      aws_api_gateway_method.cors_signup,
      aws_api_gateway_integration.cors_signup,
      aws_api_gateway_method_response.cors_signup,
      aws_api_gateway_integration_response.cors_signup,
      aws_api_gateway_method.cors_users,
      aws_api_gateway_integration.cors_users,
      aws_api_gateway_method_response.cors_users,
      aws_api_gateway_integration_response.cors_users,
      aws_api_gateway_gateway_response.cors_4xx,
      aws_api_gateway_gateway_response.cors_5xx,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment

  dynamic "access_log_settings" {
    for_each = var.create_logs_for_apigw ? [1] : []

    content {
      destination_arn = aws_cloudwatch_log_group.api_gw_logs[0].arn
      format = jsonencode({
        requestId         = "$context.requestId",
        extendedRequestId = "$context.extendedRequestId",
        ip                = "$context.identity.sourceIp",
        caller            = "$context.identity.caller",
        user              = "$context.identity.user",
        requestTime       = "$context.requestTime",
        httpMethod        = "$context.httpMethod",
        resourcePath      = "$context.resourcePath",
        status            = "$context.status",
        protocol          = "$context.protocol",
        responseLength    = "$context.responseLength"
      })
    }

  }
}

resource "aws_api_gateway_domain_name" "this" {
  count = local.create_resource_based_on_domain_name

  domain_name              = aws_acm_certificate.api[0].domain_name
  regional_certificate_arn = aws_acm_certificate_validation.api[0].certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "this" {
  count = local.create_resource_based_on_domain_name

  api_id      = aws_api_gateway_rest_api.this.id
  domain_name = aws_api_gateway_domain_name.this[0].domain_name
  stage_name  = aws_api_gateway_stage.this.stage_name
}

# Logs
resource "aws_api_gateway_account" "this" {
  count = var.create_logs_for_apigw ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.apigw_send_logs_cw[0].arn
}

# CORS
resource "aws_api_gateway_method" "cors" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.todos.id
  authorization = "NONE"
  http_method   = "OPTIONS"
}

resource "aws_api_gateway_integration" "cors" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.todos.id
  http_method = aws_api_gateway_method.cors.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.todos.id
  http_method = aws_api_gateway_method.cors.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Credentials" = true
    "method.response.header.Access-Control-Allow-Headers"     = false
    "method.response.header.Access-Control-Allow-Methods"     = false
    "method.response.header.Access-Control-Allow-Origin"      = false
  }
}

resource "aws_api_gateway_integration_response" "cors" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.todos.id
  http_method = aws_api_gateway_method.cors.http_method
  status_code = aws_api_gateway_method_response.cors.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = local.formatted_cors.headers
    "method.response.header.Access-Control-Allow-Methods"     = local.formatted_cors.methods
    "method.response.header.Access-Control-Allow-Origin"      = local.formatted_cors.origins
    "method.response.header.Access-Control-Allow-Credentials" = local.formatted_cors.credentials
  }

  depends_on = [aws_api_gateway_integration.cors]
}

resource "aws_api_gateway_method" "cors_todo" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.todo.id
  authorization = "NONE"
  http_method   = "OPTIONS"
}

resource "aws_api_gateway_integration" "cors_todo" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.todo.id
  http_method = aws_api_gateway_method.cors_todo.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors_todo" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.todo.id
  http_method = aws_api_gateway_method.cors_todo.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Credentials" = true
    "method.response.header.Access-Control-Allow-Headers"     = false
    "method.response.header.Access-Control-Allow-Methods"     = false
    "method.response.header.Access-Control-Allow-Origin"      = false
  }
}

resource "aws_api_gateway_integration_response" "cors_todo" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.todo.id
  http_method = aws_api_gateway_method.cors_todo.http_method
  status_code = aws_api_gateway_method_response.cors_todo.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = local.formatted_cors.headers
    "method.response.header.Access-Control-Allow-Methods"     = local.formatted_cors.methods
    "method.response.header.Access-Control-Allow-Origin"      = local.formatted_cors.origins
    "method.response.header.Access-Control-Allow-Credentials" = local.formatted_cors.credentials
  }

  depends_on = [aws_api_gateway_integration.cors_todo]
}

# CORS for Auth endpoints
resource "aws_api_gateway_method" "cors_signup" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.signup.id
  authorization = "NONE"
  http_method   = "OPTIONS"
}

resource "aws_api_gateway_integration" "cors_signup" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.signup.id
  http_method = aws_api_gateway_method.cors_signup.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors_signup" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.signup.id
  http_method = aws_api_gateway_method.cors_signup.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Credentials" = true
    "method.response.header.Access-Control-Allow-Headers"     = false
    "method.response.header.Access-Control-Allow-Methods"     = false
    "method.response.header.Access-Control-Allow-Origin"      = false
  }
}

resource "aws_api_gateway_integration_response" "cors_signup" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.signup.id
  http_method = aws_api_gateway_method.cors_signup.http_method
  status_code = aws_api_gateway_method_response.cors_signup.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = local.formatted_cors.headers
    "method.response.header.Access-Control-Allow-Methods"     = local.formatted_cors.methods
    "method.response.header.Access-Control-Allow-Origin"      = local.formatted_cors.origins
    "method.response.header.Access-Control-Allow-Credentials" = local.formatted_cors.credentials
  }

  depends_on = [aws_api_gateway_integration.cors_signup]
}

# CORS for Users endpoints
resource "aws_api_gateway_method" "cors_users" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.users.id
  authorization = "NONE"
  http_method   = "OPTIONS"
}

resource "aws_api_gateway_integration" "cors_users" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.cors_users.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors_users" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.cors_users.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Credentials" = true
    "method.response.header.Access-Control-Allow-Headers"     = false
    "method.response.header.Access-Control-Allow-Methods"     = false
    "method.response.header.Access-Control-Allow-Origin"      = false
  }
}

resource "aws_api_gateway_integration_response" "cors_users" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.cors_users.http_method
  status_code = aws_api_gateway_method_response.cors_users.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = local.formatted_cors.headers
    "method.response.header.Access-Control-Allow-Methods"     = local.formatted_cors.methods
    "method.response.header.Access-Control-Allow-Origin"      = local.formatted_cors.origins
    "method.response.header.Access-Control-Allow-Credentials" = local.formatted_cors.credentials
  }

  depends_on = [aws_api_gateway_integration.cors_users]
}

resource "aws_api_gateway_gateway_response" "cors_4xx" {
  response_type = "DEFAULT_4XX"
  rest_api_id   = aws_api_gateway_rest_api.this.id

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers"     = local.formatted_cors.headers
    "gatewayresponse.header.Access-Control-Allow-Methods"     = local.formatted_cors.methods
    "gatewayresponse.header.Access-Control-Allow-Origin"      = local.formatted_cors.origins
    "gatewayresponse.header.Access-Control-Allow-Credentials" = local.formatted_cors.credentials
  }
}

resource "aws_api_gateway_gateway_response" "cors_5xx" {
  response_type = "DEFAULT_5XX"
  rest_api_id   = aws_api_gateway_rest_api.this.id

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers"     = local.formatted_cors.headers
    "gatewayresponse.header.Access-Control-Allow-Methods"     = local.formatted_cors.methods
    "gatewayresponse.header.Access-Control-Allow-Origin"      = local.formatted_cors.origins
    "gatewayresponse.header.Access-Control-Allow-Credentials" = local.formatted_cors.credentials
  }
}
