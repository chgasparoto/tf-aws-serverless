import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from '@aws-sdk/client-secrets-manager';
import { ThirdPartyServiceResponse } from 'types';

export class ThirdPartyService {
  private secretsClient: SecretsManagerClient;

  constructor() {
    this.secretsClient = new SecretsManagerClient({});
  }

  async getCredentials(secretName: string): Promise<any> {
    const command = new GetSecretValueCommand({
      SecretId: secretName,
    });

    try {
      const response = await this.secretsClient.send(command);
      if (response.SecretString) {
        return JSON.parse(response.SecretString);
      }
      throw new Error('Secret value is not a string');
    } catch (error) {
      console.error('Error retrieving secret:', error);
      throw new Error(
        `Failed to retrieve credentials from Secrets Manager: ${secretName}`,
      );
    }
  }

  async callThirdPartyService(
    credentials: any,
    endpoint: string,
    method: string = 'GET',
    data?: any,
  ): Promise<ThirdPartyServiceResponse> {
    try {
      // This is a generic implementation - you'll need to customize based on your specific third-party service
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
      };

      // Add authentication headers based on credentials type
      if (credentials.apiKey) {
        headers['Authorization'] = `Bearer ${credentials.apiKey}`;
      } else if (credentials.username && credentials.password) {
        const basicAuth = Buffer.from(
          `${credentials.username}:${credentials.password}`,
        ).toString('base64');
        headers['Authorization'] = `Basic ${basicAuth}`;
      }

      const requestOptions: RequestInit = {
        method,
        headers,
      };

      if (data && method !== 'GET') {
        requestOptions.body = JSON.stringify(data);
      }

      const response = await fetch(endpoint, requestOptions);

      if (!response.ok) {
        throw new Error(
          `Third-party service responded with status: ${response.status}`,
        );
      }

      const responseData = await response.json();

      return {
        success: true,
        data: responseData,
      };
    } catch (error) {
      console.error('Error calling third-party service:', error);
      return {
        success: false,
        message:
          error instanceof Error ? error.message : 'Unknown error occurred',
      };
    }
  }

  // Example method for a specific third-party service
  async callExampleService(
    credentials: any,
    userId: string,
  ): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/users/${userId}`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }
}
