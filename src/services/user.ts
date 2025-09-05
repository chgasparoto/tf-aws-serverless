import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { User } from 'types';

export class UserService {
  private client: DynamoDBDocumentClient;
  private tableName: string;

  constructor(tableName: string) {
    this.tableName = tableName;
    this.client = DynamoDBDocumentClient.from(new DynamoDBClient({}));
  }
  async findByUserId(userId: string): Promise<User | null> {
    const command = new GetCommand({
      TableName: this.tableName,
      Key: {
        PK: `USER#${userId}`,
        SK: `USER#${userId}`,
      },
    });

    const response = await this.client.send(command);
    return (response.Item as User) || null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const command = new GetCommand({
      TableName: this.tableName,
      Key: {
        PK: `USER#${email}`,
        SK: `USER#${email}`,
      },
    });

    const response = await this.client.send(command);
    return (response.Item as User) || null;
  }

  async create(user: User): Promise<User> {
    const timestamp = new Date().toISOString();
    const userWithTimestamps = {
      ...user,
      CreatedAt: timestamp,
      UpdatedAt: timestamp,
    };

    const command = new PutCommand({
      TableName: this.tableName,
      Item: {
        PK: `USER#${user.UserId}`,
        SK: `USER#${user.UserId}`,
        ...userWithTimestamps,
      },
    });

    await this.client.send(command);
    return userWithTimestamps;
  }

  async updateThirdPartyCredentials(
    userId: string,
    credentials: string,
  ): Promise<void> {
    const timestamp = new Date().toISOString();

    const command = new UpdateCommand({
      TableName: this.tableName,
      Key: {
        PK: `USER#${userId}`,
        SK: `USER#${userId}`,
      },
      UpdateExpression:
        'SET ThirdPartyServiceCredentials = :credentials, UpdatedAt = :timestamp',
      ExpressionAttributeValues: {
        ':credentials': credentials,
        ':timestamp': timestamp,
      },
    });

    await this.client.send(command);
  }

  async updateThirdPartyService(
    userId: string,
    serviceId: string,
    credentials: string,
  ): Promise<void> {
    const timestamp = new Date().toISOString();

    const command = new UpdateCommand({
      TableName: this.tableName,
      Key: {
        PK: `USER#${userId}`,
        SK: `USER#${userId}`,
      },
      UpdateExpression:
        'SET ThirdPartyServiceId = :serviceId, ThirdPartyServiceCredentials = :credentials, UpdatedAt = :timestamp',
      ExpressionAttributeValues: {
        ':serviceId': serviceId,
        ':credentials': credentials,
        ':timestamp': timestamp,
      },
    });

    await this.client.send(command);
  }
}
