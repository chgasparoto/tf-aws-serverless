# Third-Party Service Integration Examples

This document provides examples of how to configure and test external service integrations using AWS Secrets Manager.

## Architecture Overview

The system supports integration with any external service through a generic `ThirdPartyService` class. Credentials are securely stored in AWS Secrets Manager and retrieved by Lambda functions at runtime.

### Flow:

1. **User Signup** → Creates user in Cognito + DynamoDB
2. **Configure Service** → User provides secret reference for external service
3. **API Calls** → Lambda retrieves credentials and calls external APIs

## Supported Services

### GitHub Integration

#### 1. Configure GitHub Credentials in Secrets Manager

First, update the secret value in AWS Secrets Manager:

```bash
# Get your GitHub personal access token from: https://github.com/settings/tokens
aws secretsmanager update-secret \
  --secret-id "your-service-name-github-credentials" \
  --secret-string '{
    "apiKey": "ghp_your_github_token_here",
    "baseUrl": "https://api.github.com",
    "username": "your-github-username",
    "service": "github"
  }'
```

#### 2. User Signup

```bash
curl -X POST https://your-api-gateway-url/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePassword123!"
  }'
```

Response:

```json
{
  "message": "User created successfully",
  "userId": "cognito-user-id",
  "email": "user@example.com",
  "tokens": {
    "idToken": "...",
    "accessToken": "...",
    "refreshToken": "..."
  }
}
```

#### 3. Configure GitHub Integration

```bash
curl -X POST https://your-api-gateway-url/v1/users/{userId} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {accessToken}" \
  -d '{
    "email": "user@example.com",
    "thirdPartyServiceId": "github",
    "thirdPartyServiceCredentials": "your-service-name-github-credentials"
  }'
```

#### 4. Use GitHub API

**Get User's Repositories:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/repos \
  -H "Authorization: Bearer {accessToken}"
```

**Get Specific Repository:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/repos/{repoName} \
  -H "Authorization: Bearer {accessToken}"
```

**Get GitHub User Info:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/user \
  -H "Authorization: Bearer {accessToken}"
```

**Create New Repository:**

```bash
curl -X POST https://your-api-gateway-url/v1/third-party/users/{userId}/repos \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {accessToken}" \
  -d '{
    "name": "my-new-repo",
    "description": "Repository created via API",
    "private": false
  }'
```

### Slack Integration

#### 1. Configure Slack Credentials

```bash
aws secretsmanager update-secret \
  --secret-id "your-service-name-slack-credentials" \
  --secret-string '{
    "apiKey": "xoxb-your-slack-bot-token",
    "baseUrl": "https://slack.com/api",
    "service": "slack"
  }'
```

#### 2. Configure User for Slack

```bash
curl -X POST https://your-api-gateway-url/v1/users/{userId} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {accessToken}" \
  -d '{
    "email": "user@example.com",
    "thirdPartyServiceId": "slack",
    "thirdPartyServiceCredentials": "your-service-name-slack-credentials"
  }'
```

#### 3. Use Slack API

**Get Channels:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/channels \
  -H "Authorization: Bearer {accessToken}"
```

**Send Message:**

```bash
curl -X POST https://your-api-gateway-url/v1/third-party/users/{userId}/message \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {accessToken}" \
  -d '{
    "channel": "#general",
    "text": "Hello from AWS Lambda!"
  }'
```

### Jira Integration

#### 1. Configure Jira Credentials

```bash
aws secretsmanager update-secret \
  --secret-id "your-service-name-jira-credentials" \
  --secret-string '{
    "apiKey": "your-jira-api-token",
    "baseUrl": "https://your-domain.atlassian.net",
    "username": "your-email@example.com",
    "service": "jira"
  }'
```

#### 2. Configure User for Jira

```bash
curl -X POST https://your-api-gateway-url/v1/users/{userId} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {accessToken}" \
  -d '{
    "email": "user@example.com",
    "thirdPartyServiceId": "jira",
    "thirdPartyServiceCredentials": "your-service-name-jira-credentials"
  }'
```

#### 3. Use Jira API

**Get Issues:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/issues \
  -H "Authorization: Bearer {accessToken}"
```

**Get Project:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/project/{projectKey} \
  -H "Authorization: Bearer {accessToken}"
```

**Create Issue:**

```bash
curl -X POST https://your-api-gateway-url/v1/third-party/users/{userId}/issue \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {accessToken}" \
  -d '{
    "fields": {
      "project": {"key": "PROJ"},
      "summary": "New issue from API",
      "description": "Created via AWS Lambda integration",
      "issuetype": {"name": "Task"}
    }
  }'
```

## Generic Service Integration

For any other service, you can use the generic endpoints:

### Configure Generic Service

```bash
aws secretsmanager update-secret \
  --secret-id "your-service-name-third-party-credentials" \
  --secret-string '{
    "apiKey": "your-api-key",
    "baseUrl": "https://api.example.com",
    "username": "your-username",
    "password": "your-password",
    "service": "example-service"
  }'
```

### Use Generic Endpoints

**Get Resources:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/resources \
  -H "Authorization: Bearer {accessToken}"
```

**Get Specific Resource:**

```bash
curl -X GET https://your-api-gateway-url/v1/third-party/users/{userId}/resource/{resourceId} \
  -H "Authorization: Bearer {accessToken}"
```

**Create Resource:**

```bash
curl -X POST https://your-api-gateway-url/v1/third-party/users/{userId}/resource \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {accessToken}" \
  -d '{"key": "value"}'
```

## Testing the Complete Flow

### 1. Deploy Infrastructure

```bash
cd infra/terraform
terraform init
terraform plan -var-file="config/dev/dev.tfvars"
terraform apply -var-file="config/dev/dev.tfvars"
```

### 2. Update Secret Values

Replace the placeholder values in Secrets Manager with real credentials.

### 3. Test GitHub Flow

```bash
# 1. Signup
USER_RESPONSE=$(curl -s -X POST https://your-api-gateway-url/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "TestPassword123!"}')

# 2. Extract tokens
ACCESS_TOKEN=$(echo $USER_RESPONSE | jq -r '.tokens.accessToken')
USER_ID=$(echo $USER_RESPONSE | jq -r '.userId')

# 3. Configure GitHub
curl -X POST https://your-api-gateway-url/v1/users/$USER_ID \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "email": "test@example.com",
    "thirdPartyServiceId": "github",
    "thirdPartyServiceCredentials": "your-service-name-github-credentials"
  }'

# 4. Get GitHub repos
curl -X GET https://your-api-gateway-url/v1/third-party/users/$USER_ID/repos \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

## Security Notes

1. **Secrets Manager**: All credentials are encrypted at rest and in transit
2. **IAM Permissions**: Lambda functions only have access to specific secrets
3. **Authentication**: All API calls require valid Cognito JWT tokens
4. **User Isolation**: Users can only access their own configured services

## Adding New Services

To add support for a new service:

1. **Add Secret**: Create a new secret in `secrets-manager.tf`
2. **Update Service**: Add service-specific methods in `ThirdPartyService`
3. **Update Lambda**: Add service handler in `third-party.ts`
4. **Update IAM**: Ensure Lambda has access to the new secret

Example for a new service:

```typescript
// In ThirdPartyService
async getNewServiceData(credentials: any): Promise<ThirdPartyServiceResponse> {
  const endpoint = `${credentials.baseUrl}/data`;
  return this.callThirdPartyService(credentials, endpoint, 'GET');
}

// In third-party.ts
case 'new-service':
  return await handleNewServiceRequest(thirdPartyService, credentials, method, pathParams, body);
```
