# AWS Serverless with Cognito Authentication and Third-Party Service Integration

This project provides a serverless architecture for AWS with Cognito user authentication and integration with third-party services using credentials stored in AWS Secrets Manager.

## Architecture Overview

The system consists of three main Lambda functions:

1. **Todo Management Lambda** (`dynamo.ts`) - Handles CRUD operations for todo items
2. **User Management Lambda** (`user-management.ts`) - Manages user profiles and third-party service credentials
3. **Third-Party Service Lambda** (`third-party.ts`) - Integrates with external services using stored credentials

## Features

- **Cognito Authentication**: JWT token validation using Cognito User Pool
- **DynamoDB Integration**: User data storage with proper indexing
- **Secrets Manager**: Secure storage of third-party service credentials
- **API Gateway**: RESTful endpoints with CORS support
- **IAM Security**: Least-privilege access policies

## API Endpoints

### User Management

- `POST /v1/users` - Create/update user profile
- `GET /v1/users/{userId}` - Get user profile
- `PUT /v1/users/{userId}` - Update user credentials

### Third-Party Service Integration

- `GET /v1/third-party/users/{userId}/resource` - List resources
- `GET /v1/third-party/users/{userId}/resource/{resourceId}` - Get specific resource
- `POST /v1/third-party/users/{userId}/resource` - Create resource
- `PUT /v1/third-party/users/{userId}/resource/{resourceId}` - Update resource
- `DELETE /v1/third-party/users/{userId}/resource/{resourceId}` - Delete resource

### Todo Management (existing)

- `GET /v1/todos` - List todos
- `POST /v1/todos` - Create todo
- `GET /v1/todos/{todoId}` - Get specific todo
- `PUT /v1/todos/{todoId}` - Update todo
- `DELETE /v1/todos/{todoId}` - Delete todo

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Build the Project

```bash
npm run build
```

### 3. Deploy Infrastructure

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

### 4. Store Third-Party Service Credentials

Store your third-party service credentials in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
    --name "my-third-party-service-credentials" \
    --description "Credentials for third-party service integration" \
    --secret-string '{"apiKey":"your-api-key","baseUrl":"https://api.example.com"}'
```

### 5. Create User Profile

After authenticating with Cognito, create a user profile:

```bash
curl -X POST https://your-api-gateway-url/v1/users \
  -H "Authorization: Bearer YOUR_COGNITO_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "thirdPartyServiceId": "service-123",
    "thirdPartyServiceCredentials": "my-third-party-service-credentials"
  }'
```

## Authentication Flow

1. User authenticates with Cognito User Pool
2. Cognito returns JWT tokens (ID, Access, Refresh)
3. Lambda functions validate JWT tokens using Cognito's public keys
4. User ID is extracted from the validated token
5. User data is retrieved from DynamoDB
6. Third-party service credentials are fetched from Secrets Manager
7. External service calls are made with the retrieved credentials

## Security Features

- **JWT Validation**: Tokens are validated against Cognito's public keys
- **User Isolation**: Users can only access their own data
- **Credential Encryption**: Third-party credentials are encrypted at rest in Secrets Manager
- **Least Privilege**: IAM policies grant minimal required permissions
- **CORS Protection**: Configured CORS headers for web applications

## Environment Variables

### Lambda Functions

- `USERS_TABLE_NAME`: DynamoDB table for user data
- `COGNITO_USER_POOL_ID`: Cognito User Pool ID
- `AWS_REGION`: AWS region for service calls
- `DEBUG`: Enable debug logging

### Third-Party Service Configuration

The `ThirdPartyService` class supports multiple authentication methods:

- **API Key**: `{"apiKey": "your-api-key"}`
- **Basic Auth**: `{"username": "user", "password": "pass"}`
- **Custom Headers**: Extend the class for your specific needs

## Customization

### Adding New Third-Party Services

1. Extend the `ThirdPartyService` class
2. Add your service-specific methods
3. Update the lambda function to handle new endpoints
4. Add corresponding API Gateway resources

### User Data Schema

The user table supports custom attributes. Extend the `UserSchema` in `src/types/user.ts` to add new fields.

## Monitoring and Logging

- **CloudWatch Logs**: All Lambda functions log to CloudWatch
- **Error Handling**: Comprehensive error handling with appropriate HTTP status codes
- **Debug Mode**: Enable detailed logging for development

## Troubleshooting

### Common Issues

1. **JWT Validation Errors**: Ensure Cognito User Pool ID is correct
2. **Secrets Manager Access**: Verify IAM permissions for the Lambda role
3. **DynamoDB Errors**: Check table names and IAM permissions
4. **CORS Issues**: Verify CORS configuration in API Gateway

### Debug Mode

Set `DEBUG=true` in your Lambda environment variables to enable detailed logging.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

ISC License - see LICENSE file for details.
