import { headers } from './common-headers';

export const successResponse = (message: any, status: number = 200) => ({
  statusCode: status,
  body: JSON.stringify(message),
  headers,
});
