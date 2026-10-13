import { handleBankWebhook } from './handler.ts';

// Deliberately inactive. No service-role key, DB connection or provider selected.
Deno.serve(handleBankWebhook);
