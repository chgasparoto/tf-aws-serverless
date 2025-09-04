import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { verify } from 'jsonwebtoken';
import jwkToPem from 'jwk-to-pem';

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

async function processUserRequest(event: APIGatewayProxyEvent): Promise<any> {
  const method = event.httpMethod;
  const pathParams = event.pathParameters;
  const body = event.body ? JSON.parse(event.body) : {};

  switch (method) {
    case 'GET':
      // GET requires authentication
      const authHeader =
        event?.headers?.Authorization || event?.headers?.authorization;
      if (!authHeader) {
        throw new Error('Authorization header required for profile access');
      }

      const token = authHeader.startsWith('Bearer ')
        ? authHeader.substring(7)
        : authHeader;

      const decodedToken = await verifyCognitoToken(token);
      const userId = decodedToken.sub;

      if (pathParams?.userId && pathParams.userId !== userId) {
        // Only allow users to access their own data
        throw new Error('Unauthorized access to user data');
      }
      return await userService.findByUserId(userId);

    case 'POST':
      // POST can be used for both new user creation and updates
      if (!body.email) {
        throw new Error('Email is required');
      }

      // Check if user already exists by email
      const existingUser = await userService.findByEmail(body.email);

      if (existingUser) {
        // User exists, require authentication for updates
        const authHeader =
          event?.headers?.Authorization || event?.headers?.authorization;
        if (!authHeader) {
          throw new Error('Authorization header required for profile updates');
        }

        const token = authHeader.startsWith('Bearer ')
          ? authHeader.substring(7)
          : authHeader;

        const decodedToken = await verifyCognitoToken(token);
        const userId = decodedToken.sub;

        // Verify the authenticated user matches the email
        if (userId !== existingUser.UserId) {
          throw new Error('Unauthorized access to user data');
        }

        // Update existing user
        await userService.updateThirdPartyCredentials(
          userId,
          body.thirdPartyServiceCredentials,
        );
        return { message: 'User credentials updated successfully' };
      } else {
        // New user creation - no authentication required
        // Generate a temporary user ID (this will be replaced when they authenticate)
        const tempUserId = `temp_${Date.now()}_${Math.random()
          .toString(36)
          .substr(2, 9)}`;

        const userData: User = {
          UserId: tempUserId,
          Email: body.email,
          ThirdPartyServiceId: body.thirdPartyServiceId,
          ThirdPartyServiceCredentials: body.thirdPartyServiceCredentials,
        };

        // Validate user data
        const validatedUser = UserSchema.parse(userData);

        // Create new user
        const createdUser = await userService.create(validatedUser);
        return {
          message:
            'User created successfully. Please authenticate to complete setup.',
          tempUserId: tempUserId,
          email: body.email,
        };
      }

    case 'PUT':
      // PUT requires authentication
      const authHeaderPut =
        event?.headers?.Authorization || event?.headers?.authorization;
      if (!authHeaderPut) {
        throw new Error('Authorization header required for profile updates');
      }

      const tokenPut = authHeaderPut.startsWith('Bearer ')
        ? authHeaderPut.substring(7)
        : authHeaderPut;

      const decodedTokenPut = await verifyCognitoToken(tokenPut);
      const userIdPut = decodedTokenPut.sub;

      if (pathParams?.userId && pathParams.userId !== userIdPut) {
        throw new Error('Unauthorized access to user data');
      }

      // Update user credentials
      if (body.thirdPartyServiceCredentials) {
        await userService.updateThirdPartyCredentials(
          userIdPut,
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
    // Process the user management request
    const result = await processUserRequest(event);

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

    if (err instanceof ZodError) {
      const message = err.issues.map((error) => error.message).join('\n');
      return errorResponse({ message }, 400);
    }

    if (err instanceof Error) {
      if (err.message.includes('Authorization header required')) {
        return errorResponse({ message: err.message }, 401);
      }
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
      if (err.message.includes('Email is required')) {
        return errorResponse({ message: err.message }, 400);
      }
    }

    return errorResponse({ message: 'Internal server error' }, 500);
  }
};
