import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { verify } from 'jsonwebtoken';
import jwkToPem from 'jwk-to-pem';

import { UserService, ThirdPartyService } from 'services';
import { successResponse, errorResponse } from 'utils';

const userService = new UserService(process.env.USERS_TABLE_NAME || '');
const thirdPartyService = new ThirdPartyService();

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

async function processThirdPartyRequest(
  userId: string,
  event: APIGatewayProxyEvent,
): Promise<any> {
  const method = event.httpMethod;
  const pathParams = event.pathParameters;
  const body = event.body ? JSON.parse(event.body) : {};

  // Get user data from DynamoDB
  const user = await userService.findByUserId(userId);
  if (!user) {
    throw new Error('User not found');
  }

  if (!user.ThirdPartyServiceCredentials) {
    throw new Error('No third-party service credentials found for user');
  }

  // Get credentials from Secrets Manager
  const credentials = await thirdPartyService.getCredentials(
    user.ThirdPartyServiceCredentials,
  );

  // Handle service-specific endpoints
  const service = credentials.service || 'generic';

  // Check if this is a GitHub-specific endpoint based on URL path
  const isGitHubEndpoint =
    event.resource?.includes('/repos') ||
    event.path?.includes('/repos') ||
    pathParams?.repoName;

  if (isGitHubEndpoint && service === 'github') {
    return await handleGitHubRequest(
      thirdPartyService,
      credentials,
      method,
      pathParams,
      body,
    );
  }

  switch (service) {
    case 'github':
      return await handleGitHubRequest(
        thirdPartyService,
        credentials,
        method,
        pathParams,
        body,
      );
    case 'slack':
      return await handleSlackRequest(
        thirdPartyService,
        credentials,
        method,
        pathParams,
        body,
      );
    case 'jira':
      return await handleJiraRequest(
        thirdPartyService,
        credentials,
        method,
        pathParams,
        body,
      );
    default:
      return await handleGenericRequest(
        thirdPartyService,
        credentials,
        method,
        pathParams,
        body,
      );
  }
}

async function handleGitHubRequest(
  thirdPartyService: ThirdPartyService,
  credentials: any,
  method: string,
  pathParams: any,
  body: any,
): Promise<any> {
  switch (method) {
    case 'GET':
      if (pathParams?.resourceId) {
        // GET /third-party/users/{userId}/repos/{repoName}
        return await thirdPartyService.getGitHubRepo(
          credentials,
          credentials.username,
          pathParams.resourceId,
        );
      } else if (pathParams?.action === 'user') {
        // GET /third-party/users/{userId}/user
        return await thirdPartyService.getGitHubUser(credentials);
      } else {
        // GET /third-party/users/{userId}/repos
        return await thirdPartyService.getGitHubRepos(credentials);
      }

    case 'POST':
      // POST /third-party/users/{userId}/repos
      return await thirdPartyService.createGitHubRepo(credentials, body);

    default:
      throw new Error(`Unsupported method "${method}" for GitHub`);
  }
}

async function handleSlackRequest(
  thirdPartyService: ThirdPartyService,
  credentials: any,
  method: string,
  pathParams: any,
  body: any,
): Promise<any> {
  switch (method) {
    case 'GET':
      if (pathParams?.action === 'channels') {
        // GET /third-party/users/{userId}/channels
        return await thirdPartyService.getSlackChannels(credentials);
      }
      throw new Error('Invalid Slack endpoint');

    case 'POST':
      if (pathParams?.action === 'message') {
        // POST /third-party/users/{userId}/message
        const { channel, text } = body;
        if (!channel || !text) {
          throw new Error('Channel and text are required for Slack message');
        }
        return await thirdPartyService.sendSlackMessage(
          credentials,
          channel,
          text,
        );
      }
      throw new Error('Invalid Slack endpoint');

    default:
      throw new Error(`Unsupported method "${method}" for Slack`);
  }
}

async function handleJiraRequest(
  thirdPartyService: ThirdPartyService,
  credentials: any,
  method: string,
  pathParams: any,
  body: any,
): Promise<any> {
  switch (method) {
    case 'GET':
      if (pathParams?.action === 'issues') {
        // GET /third-party/users/{userId}/issues
        const jql = pathParams?.jql;
        return await thirdPartyService.getJiraIssues(credentials, jql);
      } else if (pathParams?.action === 'project' && pathParams?.projectKey) {
        // GET /third-party/users/{userId}/project/{projectKey}
        return await thirdPartyService.getJiraProject(
          credentials,
          pathParams.projectKey,
        );
      }
      throw new Error('Invalid Jira endpoint');

    case 'POST':
      if (pathParams?.action === 'issue') {
        // POST /third-party/users/{userId}/issue
        return await thirdPartyService.createJiraIssue(credentials, body);
      }
      throw new Error('Invalid Jira endpoint');

    default:
      throw new Error(`Unsupported method "${method}" for Jira`);
  }
}

async function handleGenericRequest(
  thirdPartyService: ThirdPartyService,
  credentials: any,
  method: string,
  pathParams: any,
  body: any,
): Promise<any> {
  switch (method) {
    case 'GET':
      if (pathParams?.resourceId) {
        // Example: GET /third-party/users/{userId}/resource/{resourceId}
        const endpoint = `${credentials.baseUrl}/resource/${pathParams.resourceId}`;
        return await thirdPartyService.callThirdPartyService(
          credentials,
          endpoint,
          'GET',
        );
      } else {
        // Example: GET /third-party/users/{userId}/resources
        const endpoint = `${credentials.baseUrl}/resources`;
        return await thirdPartyService.callThirdPartyService(
          credentials,
          endpoint,
          'GET',
        );
      }

    case 'POST':
      // Example: POST /third-party/users/{userId}/resource
      const endpoint = `${credentials.baseUrl}/resource`;
      return await thirdPartyService.callThirdPartyService(
        credentials,
        endpoint,
        'POST',
        body,
      );

    case 'PUT':
      if (pathParams?.resourceId) {
        // Example: PUT /third-party/users/{userId}/resource/{resourceId}
        const endpoint = `${credentials.baseUrl}/resource/${pathParams.resourceId}`;
        return await thirdPartyService.callThirdPartyService(
          credentials,
          endpoint,
          'PUT',
          body,
        );
      }
      throw new Error('Resource ID required for PUT requests');

    case 'DELETE':
      if (pathParams?.resourceId) {
        // Example: DELETE /third-party/users/{userId}/resource/{resourceId}
        const endpoint = `${credentials.baseUrl}/resource/${pathParams.resourceId}`;
        return await thirdPartyService.callThirdPartyService(
          credentials,
          endpoint,
          'DELETE',
        );
      }
      throw new Error('Resource ID required for DELETE requests');

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

    // Process the third-party service request
    const result = await processThirdPartyRequest(userId, event);

    console.log({
      message: 'Third-party service response',
      data: JSON.stringify(result),
    });

    if (!result.success) {
      return errorResponse({ message: result.message }, 400);
    }

    return successResponse(result.data, 200);
  } catch (err) {
    console.error({
      message: 'Error while processing event',
      data: err,
    });

    if (err instanceof Error) {
      if (
        err.message.includes('Invalid token') ||
        err.message.includes('No matching key found')
      ) {
        return errorResponse({ message: 'Unauthorized' }, 401);
      }
      if (err.message.includes('User not found')) {
        return errorResponse({ message: 'User not found' }, 404);
      }
      if (err.message.includes('No third-party service credentials')) {
        return errorResponse(
          { message: 'Service not configured for user' },
          400,
        );
      }
      if (err.message.includes('Resource ID required')) {
        return errorResponse({ message: err.message }, 400);
      }
      if (err.message.includes('Unsupported method')) {
        return errorResponse({ message: err.message }, 405);
      }
    }

    return errorResponse({ message: 'Internal server error' }, 500);
  }
};
