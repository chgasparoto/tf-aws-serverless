resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub's root CA thumbprint
}

resource "aws_iam_role" "terraform_dev" {
  name = "terraform-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # allow PRs and feature branches
            "token.actions.githubusercontent.com:sub" = "repo:chgasparoto/tf-aws-serverless:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_dev_policy" {
  role       = aws_iam_role.terraform_dev.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # 🔒 replace with least privilege later
}

resource "aws_iam_role" "terraform_prod" {
  name = "terraform-prod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" = "repo:chgasparoto/tf-aws-serverless:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_prod_policy" {
  role       = aws_iam_role.terraform_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # 🔒 tighten permissions later
}
