import { z } from 'zod';

export const UserSchema = z.object({
  UserId: z.string(),
  Email: z.string().email(),
  ThirdPartyServiceId: z.string().optional(),
  ThirdPartyServiceCredentials: z.string().optional(), // Reference to Secrets Manager
  CreatedAt: z.string().optional(),
  UpdatedAt: z.string().optional(),
});

export type User = z.infer<typeof UserSchema>;

export const ThirdPartyServiceResponseSchema = z.object({
  success: z.boolean(),
  data: z.any().optional(),
  message: z.string().optional(),
});

export type ThirdPartyServiceResponse = z.infer<
  typeof ThirdPartyServiceResponseSchema
>;
