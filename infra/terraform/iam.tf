data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

module "iam_role_dynamodb_lambda" {
  source = "./modules/iam"

  iam_role_name   = "${local.namespaced_service_name}-dynamodb-lambda-role"
  iam_policy_name = "${local.namespaced_service_name}-dynamodb-lambda-execute-policy"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  create_log_perms_for_lambda = true

  permissions = [
    {
      sid = "AllowDynamoDBActions"
      actions = [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
      ]
      resources = [
        "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${aws_dynamodb_table.this.name}",
        "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${aws_dynamodb_table.this.name}/index/*",
      ]
    }
  ]
}

resource "aws_iam_role" "apigw_send_logs_cw" {
  count = var.create_logs_for_apigw ? 1 : 0

  name        = "AllowApiGatewaySendLogsToCloudWatch"
  description = "Allows API Gateway to push logs to Cloudwatch"


  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowApiGatewaySendLogsToCloudWatch"
        Action    = "sts:AssumeRole",
        Effect    = "Allow"
        Principal = { Service = "apigateway.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apigw_send_logs_cw" {
  count = var.create_logs_for_apigw ? 1 : 0

  role       = aws_iam_role.apigw_send_logs_cw[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
