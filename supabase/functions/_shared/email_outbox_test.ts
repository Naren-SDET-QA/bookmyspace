import { deterministicEmailKey } from './email_outbox.ts';

Deno.test('email event keys are deterministic', () => {
  const a = deterministicEmailKey('booking.confirmed', 'booking-1', 'customer');
  const b = deterministicEmailKey('booking.confirmed', 'booking-1', 'customer');
  if (a !== b) throw new Error('same event produced different keys');
  if (a === deterministicEmailKey('booking.confirmed', 'booking-1', 'owner')) throw new Error('audiences collided');
});
