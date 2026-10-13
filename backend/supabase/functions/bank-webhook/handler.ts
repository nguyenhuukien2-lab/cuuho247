// GD6C inactive endpoint shell. NO ingress path reaches the processor.
// Enabling requires a real adapter, authenticated account contract and reviewed
// server DB transport. No environment toggle can enable this implementation.
const maxBodyBytes = 64 * 1024;
const bodyDeadlineMs = 5000;
const reply = (status: number, message: string, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...extra },
  });

export async function handleBankWebhook(request: Request): Promise<Response> {
  if (request.method !== 'POST') return reply(405, 'method_not_allowed', { Allow: 'POST' });
  const size = request.headers.get('content-length');
  if (size != null && (!/^\d+$/.test(size) || BigInt(size) > BigInt(maxBodyBytes))) return reply(413, 'request_too_large');
  // Provisional shell supports JSON only; actual media/auth contract is a blocker.
  if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json') return reply(415, 'unsupported_media_type');
  if (request.headers.has('content-encoding')) return reply(415, 'unsupported_media_type');
  const reader = request.body?.getReader();
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    if (reader) {
      const deadline = new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('body_deadline')), bodyDeadlineMs);
      });
      let total = 0;
      while (true) {
        const chunk = await Promise.race([reader.read(), deadline]);
        if (chunk.done) break;
        total += chunk.value.byteLength;
        if (total > maxBodyBytes) return reply(413, 'request_too_large');
      }
    }
    return reply(503, 'verification_unavailable');
  } catch {
    return reply(400, 'invalid_request');
  } finally {
    if (timer) clearTimeout(timer);
    // Never await a malicious/unfinished request stream's cancellation.
    if (reader) void reader.cancel().catch(() => {});
  }
}
