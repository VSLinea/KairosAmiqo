import { z } from 'zod';

// Negotiation state machine values
export const NegotiationStateSchema = z.enum([
  'awaiting_invites',
  'awaiting_replies',
  'confirmed',
  'cancelled',
  'expired',
]);

// Intent categories
export const IntentCategorySchema = z.enum([
  'coffee',
  'lunch',
  'dinner',
  'drinks',
  'gym',
  'walk',
  'movie',
  'concert',
  'study',
  'game',
  'brunch',
]);

// Participant status values
export const ParticipantStatusSchema = z.enum([
  'invited',
  'accepted',
  'rejected',
  'countered',
  'organizer',
]);

// POST /negotiate/start request schema
export const StartNegotiationRequestSchema = z.object({
  negotiation_id: z.string().uuid('Invalid UUID format for negotiation_id'),
  intent_category: IntentCategorySchema,
  participant_count: z.number().int().min(2, 'At least 2 participants required'),
  proposed_slots: z.array(
    z.object({
      starts_at: z.string().datetime({ message: 'Invalid ISO 8601 datetime' }),
      duration_minutes: z.number().int().positive().optional(),
    })
  ).min(1, 'At least one proposed slot required'),
  proposed_venues: z.array(
    z.object({
      venue_name: z.string().min(1),
      venue_metadata: z.record(z.string(), z.unknown()).optional(),
    })
  ).optional(),
  expires_at: z.string().datetime({ message: 'Invalid ISO 8601 datetime' }),
  encrypted_payload: z.string().min(1, 'encrypted_payload required'),
  agent_mode: z.boolean().default(false),
});

export type StartNegotiationRequest = z.infer<typeof StartNegotiationRequestSchema>;

// POST /negotiate/reply request schema
export const ReplyNegotiationRequestSchema = z.object({
  negotiation_id: z.string().uuid('Invalid UUID format for negotiation_id'),
  action: z.enum(['accept', 'reject', 'counter']),
  encrypted_payload: z.string().min(1, 'encrypted_payload required'),
  counter_payload: z.string().optional(),
  selected_slot_index: z.number().int().min(0).optional(),
  selected_venue_index: z.number().int().min(0).optional(),
});

export type ReplyNegotiationRequest = z.infer<typeof ReplyNegotiationRequestSchema>;

// GET /negotiations query parameters
export const ListNegotiationsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().optional(),
  state: NegotiationStateSchema.optional(),
  updated_after: z.string().datetime().optional(),
  updated_before: z.string().datetime().optional(),
});

export type ListNegotiationsQuery = z.infer<typeof ListNegotiationsQuerySchema>;

// Event status values
export const EventStatusSchema = z.enum(['draft', 'confirmed', 'cancelled']);

// GET /events query parameters
export const ListEventsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().optional(),
  status: EventStatusSchema.optional(),
  starts_after: z.string().datetime().optional(),
  starts_before: z.string().datetime().optional(),
});

export type ListEventsQuery = z.infer<typeof ListEventsQuerySchema>;
