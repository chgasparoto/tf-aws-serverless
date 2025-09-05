import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminCreateUserCommand,
  AdminSetUserPasswordCommand,
  AdminInitiateAuthCommand,
  AuthFlowType,
} from '@aws-sdk/client-cognito-identity-provider';

import { UserService } from 'services';
import { User, UserSchema } from 'types';
import { successResponse, errorResponse } from 'utils';

const cognitoClient = new CognitoIdentityProviderClient({});
const userService = new UserService(process.env.USERS_TABLE_NAME || '');

const SignupRequestSchema = {
  email: (value: string) => {
    if (!value || typeof value !== 'string') {
      throw new Error('Email is required');
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(value)) {
      throw new Error('Invalid email format');
    }
    return value;
  },
  password: (value: string) => {
    if (!value || typeof value !== 'string') {
      throw new Error('Password is required');
    }
    if (value.length < 8) {
      throw new Error('Password must be at least 8 characters long');
    }
    return value;
  },
};

async function createCognitoUser(
  email: string,
  password: string,
): Promise<string> {
  const userPoolId = process.env.COGNITO_USER_POOL_ID;
  const clientId = process.env.COGNITO_CLIENT_ID;

  if (!userPoolId || !clientId) {
    throw new Error('Cognito configuration missing');
  }

  try {
    // Create user in Cognito
    const createUserCommand = new AdminCreateUserCommand({
      UserPoolId: userPoolId,
      Username: email,
      UserAttributes: [
        {
          Name: 'email',
          Value: email,
        },
        {
          Name: 'email_verified',
          Value: 'true',
        },
      ],
      MessageAction: 'SUPPRESS', // Don't send welcome email
      TemporaryPassword: password,
    });

    const createUserResponse = await cognitoClient.send(createUserCommand);
    const cognitoUserId = createUserResponse.User?.Username;

    if (!cognitoUserId) {
      throw new Error('Failed to create user in Cognito');
    }

    // Set permanent password
    const setPasswordCommand = new AdminSetUserPasswordCommand({
      UserPoolId: userPoolId,
      Username: email,
      Password: password,
      Permanent: true,
    });

    await cognitoClient.send(setPasswordCommand);

    return cognitoUserId;
  } catch (error: any) {
    if (error.name === 'UsernameExistsException') {
      throw new Error('User already exists');
    }
    throw new Error(`Failed to create user: ${error.message}`);
  }
}

async function authenticateUser(email: string, password: string): Promise<any> {
  const userPoolId = process.env.COGNITO_USER_POOL_ID;
  const clientId = process.env.COGNITO_CLIENT_ID;

  if (!userPoolId || !clientId) {
    throw new Error('Cognito configuration missing');
  }

  try {
    const authCommand = new AdminInitiateAuthCommand({
      UserPoolId: userPoolId,
      ClientId: clientId,
      AuthFlow: AuthFlowType.ADMIN_NO_SRP_AUTH,
      AuthParameters: {
        USERNAME: email,
        PASSWORD: password,
      },
    });

    const authResponse = await cognitoClient.send(authCommand);
    return authResponse.AuthenticationResult;
  } catch (error: any) {
    throw new Error(`Authentication failed: ${error.message}`);
  }
}

async function createUserInDynamoDB(
  cognitoUserId: string,
  email: string,
): Promise<User> {
  const userData: User = {
    UserId: cognitoUserId,
    Email: email,
  };

  // Validate user data
  const validatedUser = UserSchema.parse(userData);

  // Create user in DynamoDB
  return await userService.create(validatedUser);
}

export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  if (process.env.DEBUG === 'true') {
    console.log({
      message: 'Signup event received',
      data: JSON.stringify(event),
    });
  }

  try {
    const body = event.body ? JSON.parse(event.body) : {};

    // Validate request body
    const email = SignupRequestSchema.email(body.email);
    const password = SignupRequestSchema.password(body.password);

    // Check if user already exists in DynamoDB
    const existingUser = await userService.findByEmail(email);
    if (existingUser) {
      return errorResponse(
        { message: 'User already exists. Please use a different email.' },
        409,
      );
    }

    // Create user in Cognito
    const cognitoUserId = await createCognitoUser(email, password);

    // Create user in DynamoDB
    const user = await createUserInDynamoDB(cognitoUserId, email);

    // Authenticate user to get tokens
    const authResult = await authenticateUser(email, password);

    if (!authResult) {
      throw new Error('Failed to authenticate user after creation');
    }

    const response = {
      message: 'User created successfully',
      userId: cognitoUserId,
      email: email,
      tokens: {
        idToken: authResult.IdToken,
        accessToken: authResult.AccessToken,
        refreshToken: authResult.RefreshToken,
        expiresIn: authResult.ExpiresIn,
        tokenType: authResult.TokenType,
      },
    };

    console.log({
      message: 'User signup successful',
      userId: cognitoUserId,
      email: email,
    });

    return successResponse(response, 201);
  } catch (err) {
    console.error({
      message: 'Error during user signup',
      data: err,
    });

    if (err instanceof Error) {
      if (err.message.includes('User already exists')) {
        return errorResponse(
          { message: 'User already exists. Please use a different email.' },
          409,
        );
      }
      if (
        err.message.includes('Email is required') ||
        err.message.includes('Password is required') ||
        err.message.includes('Invalid email format') ||
        err.message.includes('Password must be at least')
      ) {
        return errorResponse({ message: err.message }, 400);
      }
      if (err.message.includes('Cognito configuration missing')) {
        return errorResponse({ message: 'Service configuration error' }, 500);
      }
    }

    return errorResponse({ message: 'Internal server error' }, 500);
  }
};
