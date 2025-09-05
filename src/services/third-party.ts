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
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'User-Agent': 'AWS-Serverless-Integration/1.0',
      };

      // Add authentication headers based on service type
      if (credentials.service === 'github') {
        headers['Authorization'] = `token ${credentials.apiKey}`;
        headers['Accept'] = 'application/vnd.github.v3+json';
      } else if (credentials.service === 'slack') {
        headers['Authorization'] = `Bearer ${credentials.apiKey}`;
      } else if (credentials.service === 'jira') {
        const basicAuth = Buffer.from(
          `${credentials.username}:${credentials.apiKey}`,
        ).toString('base64');
        headers['Authorization'] = `Basic ${basicAuth}`;
      } else if (credentials.apiKey) {
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
        const errorText = await response.text();
        throw new Error(
          `Third-party service responded with status: ${response.status} - ${errorText}`,
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

  // GitHub-specific methods
  async getGitHubRepos(credentials: any): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/user/repos?sort=updated&per_page=10`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }

  async getGitHubUser(credentials: any): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/user`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }

  async getGitHubRepo(
    credentials: any,
    owner: string,
    repo: string,
  ): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/repos/${owner}/${repo}`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }

  async createGitHubRepo(
    credentials: any,
    repoData: any,
  ): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/user/repos`;
    return this.callThirdPartyService(credentials, endpoint, 'POST', repoData);
  }

  // Slack-specific methods
  async sendSlackMessage(
    credentials: any,
    channel: string,
    text: string,
  ): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/chat.postMessage`;
    const data = {
      channel,
      text,
    };
    return this.callThirdPartyService(credentials, endpoint, 'POST', data);
  }

  async getSlackChannels(credentials: any): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/conversations.list`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }

  // Jira-specific methods
  async getJiraIssues(
    credentials: any,
    jql?: string,
  ): Promise<ThirdPartyServiceResponse> {
    const query = jql || 'assignee = currentUser() ORDER BY updated DESC';
    const endpoint = `${
      credentials.baseUrl
    }/rest/api/3/search?jql=${encodeURIComponent(query)}`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }

  async getJiraProject(
    credentials: any,
    projectKey: string,
  ): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/rest/api/3/project/${projectKey}`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }

  async createJiraIssue(
    credentials: any,
    issueData: any,
  ): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/rest/api/3/issue`;
    return this.callThirdPartyService(credentials, endpoint, 'POST', issueData);
  }

  // Generic method for any service
  async callExampleService(
    credentials: any,
    userId: string,
  ): Promise<ThirdPartyServiceResponse> {
    const endpoint = `${credentials.baseUrl}/users/${userId}`;
    return this.callThirdPartyService(credentials, endpoint, 'GET');
  }
}
