import { z } from 'zod';

// ============================================================================
// Negotiation Lifecycle State Schema (Canonical Phase 3)
// ============================================================================
// Valid values match Prisma schema and iOS Swift enums
// See: docs/01-data-model.md, docs/02-terminology.md
export const NegotiationStateSchema = z.enum([
  'awaiting_invites',  // Negotiation created, invites not yet sent
  'awaiting_replies',  // Invites sent, waiting for participant responses
  'confirmed',         // All participants accepted, event created
  'cancelled',         // Manually cancelled by owner
  'expired',           // Deadline passed without consensus
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
  'declined',
  'organizer',
]);

// POST /negotiate/start request schema
const ProposedSlotInputSchema = z.object({
  start_time: z.string().datetime({ message: 'Invalid ISO 8601 datetime for start_time' }),
  end_time: z.string().datetime({ message: 'Invalid ISO 8601 datetime for end_time' }),
}).refine((slot) => new Date(slot.end_time).getTime() > new Date(slot.start_time).getTime(), {
  message: 'end_time must be after start_time',
  path: ['end_time'],
});

const ProposedVenueInputSchema = z.object({
  venue_name: z.string().min(1, 'venue_name is required'),
  venue_metadata: z.record(z.string(), z.unknown()).optional(),
});

export const StartNegotiationRequestSchema = z.object({
  negotiation_id: z.string().uuid('Invalid UUID format for negotiation_id'),
  title: z.string().max(120, 'title must be 120 characters or fewer').optional(),
  intent_category: IntentCategorySchema,
  participant_ids: z.array(z.string().uuid('participant_ids must contain valid UUIDs')).min(1, 'At least 1 invitee required'),
  proposed_slots: z.array(ProposedSlotInputSchema).min(1, 'At least one proposed slot required'),
  proposed_venues: z.array(ProposedVenueInputSchema).optional(),
  expires_at: z.string().datetime({ message: 'Invalid ISO 8601 datetime' }),
  encrypted_payload: z.string().min(1, 'encrypted_payload required').optional(),
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

// ============================================================================
// Event Lifecycle Status Schema (Canonical Phase 3)
// ============================================================================
// Valid values match Prisma schema and iOS Swift enums
// See: docs/01-data-model.md
export const EventStatusSchema = z.enum([
  'draft',      // Event not yet published
  'confirmed',  // Event published and active
  'cancelled',  // Event cancelled
]);

// GET /events/upcoming query parameters
export const ListUpcomingEventsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  after: z.string().datetime().optional(),
});

export type ListUpcomingEventsQuery = z.infer<typeof ListUpcomingEventsQuerySchema>;

// GET /events query parameters
export const ListEventsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().optional(),
  status: EventStatusSchema.optional(),
  starts_after: z.string().datetime().optional(),
  starts_before: z.string().datetime().optional(),
});

export type ListEventsQuery = z.infer<typeof ListEventsQuerySchema>;
