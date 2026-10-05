import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !anonKey) {
  throw new Error('Thiếu VITE_SUPABASE_URL hoặc VITE_SUPABASE_ANON_KEY')
}

export const supabase = createClient(url, anonKey)

export async function isAdmin() {
  const { data, error } = await supabase.rpc('is_admin')
  if (error) throw error
  return data === true
}
