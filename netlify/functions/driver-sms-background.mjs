import { runQueuedBatch } from './driver-sms.mjs';

export async function handler(event) {
  await runQueuedBatch(event);
  return { statusCode: 200 };
}
