# --------------- SECRETS MANAGER --------------------

# GitHub API credentials secret
resource "aws_secretsmanager_secret" "github_credentials" {
  name                    = "${local.namespaced_service_name}-github-credentials"
  description             = "GitHub API credentials for third-party integration"
  recovery_window_in_days = 7
}

# Example secret value (you'll need to update this with real credentials)
resource "aws_secretsmanager_secret_version" "github_credentials" {
  secret_id = aws_secretsmanager_secret.github_credentials.id
  secret_string = jsonencode({
    apiKey   = "your-github-token-here"
    baseUrl  = "https://api.github.com"
    username = "your-github-username"
    service  = "github"
  })
}

# Generic third-party service credentials secret
resource "aws_secretsmanager_secret" "third_party_credentials" {
  name                    = "${local.namespaced_service_name}-third-party-credentials"
  description             = "Generic third-party service credentials"
  recovery_window_in_days = 7
}

# Example secret value for other services
resource "aws_secretsmanager_secret_version" "third_party_credentials" {
  secret_id = aws_secretsmanager_secret.third_party_credentials.id
  secret_string = jsonencode({
    apiKey   = "your-api-key-here"
    baseUrl  = "https://api.example.com"
    username = "your-username"
    password = "your-password"
    service  = "example-service"
  })
}

# Slack API credentials secret
resource "aws_secretsmanager_secret" "slack_credentials" {
  name                    = "${local.namespaced_service_name}-slack-credentials"
  description             = "Slack API credentials for third-party integration"
  recovery_window_in_days = 7
}

# Example Slack secret value
resource "aws_secretsmanager_secret_version" "slack_credentials" {
  secret_id = aws_secretsmanager_secret.slack_credentials.id
  secret_string = jsonencode({
    apiKey  = "your-slack-bot-token-here"
    baseUrl = "https://slack.com/api"
    service = "slack"
  })
}

# Jira API credentials secret
resource "aws_secretsmanager_secret" "jira_credentials" {
  name                    = "${local.namespaced_service_name}-jira-credentials"
  description             = "Jira API credentials for third-party integration"
  recovery_window_in_days = 7
}

# Example Jira secret value
resource "aws_secretsmanager_secret_version" "jira_credentials" {
  secret_id = aws_secretsmanager_secret.jira_credentials.id
  secret_string = jsonencode({
    apiKey   = "your-jira-api-token-here"
    baseUrl  = "https://your-domain.atlassian.net"
    username = "your-email@example.com"
    service  = "jira"
  })
}
