import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { verify } from 'jsonwebtoken';
import { jwkToPem } from 'jwk-to-pem';

import { UserService } from 'services';
import { User, UserSchema } from 'types';
import { successResponse, errorResponse } from 'utils';
import { ZodError } from 'zod';

const userService = new UserService(process.env.USERS_TABLE_NAME || '');

// Cache for JWK keys
let jwkCache: any = null;
let jwkCacheExpiry: number = 0;

async function getJwkKeys(): Promise<any> {
  const now = Date.now();

  if (jwkCache && now < jwkCacheExpiry) {
    return jwkCache;
  }

  try {
    const userPoolId = process.env.COGNITO_USER_POOL_ID;
    const region = process.env.AWS_REGION;

    const jwksUrl = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}/.well-known/jwks.json`;

    const response = await fetch(jwksUrl);
    const jwks = await response.json();

    jwkCache = jwks;
    jwkCacheExpiry = now + 60 * 60 * 1000; // Cache for 1 hour

    return jwks;
  } catch (error) {
    console.error('Error fetching JWK keys:', error);
    throw new Error('Failed to fetch JWK keys');
  }
}

async function verifyCognitoToken(token: string): Promise<any> {
  try {
    const jwks = await getJwkKeys();

    // Decode the token header to get the key ID
    const decodedHeader = JSON.parse(
      Buffer.from(token.split('.')[0], 'base64').toString(),
    );
    const keyId = decodedHeader.kid;

    // Find the matching key
    const key = jwks.keys.find((k: any) => k.kid === keyId);
    if (!key) {
      throw new Error('No matching key found');
    }

    // Convert JWK to PEM
    const pem = jwkToPem(key);

    // Verify the token
    const verified = verify(token, pem, { algorithms: ['RS256'] });
    return verified;
  } catch (error) {
    console.error('Error verifying token:', error);
    throw new Error('Invalid token');
  }
}

async function processUserRequest(
  userId: string,
  event: APIGatewayProxyEvent,
): Promise<any> {
  const method = event.httpMethod;
  const pathParams = event.pathParameters;
  const body = event.body ? JSON.parse(event.body) : {};

  switch (method) {
    case 'GET':
      if (pathParams?.userId && pathParams.userId !== userId) {
        // Only allow users to access their own data
        throw new Error('Unauthorized access to user data');
      }
      return await userService.findByUserId(userId);

    case 'POST':
      // Create or update user profile
      const userData: User = {
        UserId: userId,
        Email: body.email,
        ThirdPartyServiceId: body.thirdPartyServiceId,
        ThirdPartyServiceCredentials: body.thirdPartyServiceCredentials,
      };

      // Validate user data
      const validatedUser = UserSchema.parse(userData);

      // Check if user already exists
      const existingUser = await userService.findByUserId(userId);
      if (existingUser) {
        // Update existing user
        await userService.updateThirdPartyCredentials(
          userId,
          body.thirdPartyServiceCredentials,
        );
        return { message: 'User credentials updated successfully' };
      } else {
        // Create new user
        return await userService.create(validatedUser);
      }

    case 'PUT':
      if (pathParams?.userId && pathParams.userId !== userId) {
        throw new Error('Unauthorized access to user data');
      }

      // Update user credentials
      if (body.thirdPartyServiceCredentials) {
        await userService.updateThirdPartyCredentials(
          userId,
          body.thirdPartyServiceCredentials,
        );
        return { message: 'User credentials updated successfully' };
      }
      throw new Error('No credentials provided for update');

    default:
      throw new Error(`Unsupported method "${method}"`);
  }
}

export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  if (process.env.DEBUG === 'true') {
    console.log({
      message: 'Event received',
      data: JSON.stringify(event),
    });
  }

  try {
    // Extract and verify the Cognito token
    const authHeader =
      event.headers.Authorization || event.headers.authorization;
    if (!authHeader) {
      return errorResponse({ message: 'Authorization header required' }, 401);
    }

    const token = authHeader.startsWith('Bearer ')
      ? authHeader.substring(7)
      : authHeader;

    const decodedToken = await verifyCognitoToken(token);
    const userId = decodedToken.sub;

    console.log({
      message: 'Decoded token',
      data: JSON.stringify(decodedToken),
    });

    // Process the user management request
    const result = await processUserRequest(userId, event);

    console.log({
      message: 'User management response',
      data: JSON.stringify(result),
    });

    return successResponse(result, 200);
  } catch (err) {
    console.error({
      message: 'Error while processing event',
      data: err,
    });

    if (err instanceof Error && err.message.includes('Invalid token')) {
      return errorResponse({ message: 'Unauthorized' }, 401);
    }

    if (err instanceof ZodError) {
      const message = err.errors.map((error) => error.message).join('\n');
      return errorResponse({ message }, 400);
    }

    if (err instanceof Error) {
      if (
        err.message.includes('Invalid token') ||
        err.message.includes('No matching key found')
      ) {
        return errorResponse({ message: 'Unauthorized' }, 401);
      }
      if (err.message.includes('Unauthorized access to user data')) {
        return errorResponse({ message: err.message }, 403);
      }
      if (err.message.includes('No credentials provided for update')) {
        return errorResponse({ message: err.message }, 400);
      }
      if (err.message.includes('Unsupported method')) {
        return errorResponse({ message: err.message }, 405);
      }
    }

    return errorResponse({ message: 'Internal server error' }, 500);
  }
};
