import { useCallback, useEffect, useId, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { apiError } from '../lib/adminApi'
import type { ApiResult } from '../lib/adminTypes'

type Loader<T> = (signal?: AbortSignal) => Promise<ApiResult<T>>
export function useAdminData<T>(loader: Loader<T>, tables: string[] = []) {
  const [state, setState] = useState<{ source: Loader<T>; data: T | null; loading: boolean; refreshing: boolean; error: string | null }>({ source: loader, data: null, loading: true, refreshing: false, error: null })
  const [realtime, setRealtime] = useState({ key: '', warning: false })
  const controller = useRef<AbortController | null>(null)
  const mounted = useRef(false)
  const channelId = useId()
  const channelSequence = useRef(0)
  const tableKey = [...new Set(tables)].sort().join(',')

  const reload = useCallback(async () => {
    controller.current?.abort()
    const current = new AbortController()
    controller.current = current
    setState((previous) => previous.source === loader ? { ...previous, refreshing: true } : { source: loader, data: null, loading: true, refreshing: true, error: null })
    try {
      const result = await loader(current.signal)
      if (!mounted.current || current.signal.aborted) return
      setState((previous) => ({ source: loader, data: result.error ? previous.data : result.data, loading: false, refreshing: false, error: result.error }))
    } catch (cause) {
      if (mounted.current && !current.signal.aborted) setState((previous) => ({ ...previous, loading: false, refreshing: false, error: apiError(cause) }))
    }
  }, [loader])

  useEffect(() => {
    mounted.current = true
    const start = setTimeout(() => void reload(), 0)
    return () => { clearTimeout(start); mounted.current = false; controller.current?.abort() }
  }, [reload])

  useEffect(() => {
    let active = true
    let timer: ReturnType<typeof setTimeout> | undefined
    const schedule = () => {
      clearTimeout(timer)
      timer = setTimeout(() => { if (active) void reload() }, 300)
    }
    // Polling also covers publication/RLS configurations that suppress events silently.
    const poll = setInterval(() => { if (!document.hidden) schedule() }, 60_000)
    window.addEventListener('focus', schedule)
    const channel = tableKey ? supabase.channel('admin-data-' + channelId + '-' + (++channelSequence.current)) : null
    try {
      for (const table of tableKey.split(',').filter(Boolean)) {
        channel?.on('postgres_changes', { event: '*', schema: 'public', table }, schedule)
      }
      channel?.subscribe((status) => {
        if (!active) return
        setRealtime({ key: tableKey, warning: status !== 'SUBSCRIBED' })
        if (status === 'SUBSCRIBED') schedule()
      })
    } catch { queueMicrotask(() => { if (active) setRealtime({ key: tableKey, warning: true }) }) }
    return () => {
      active = false
      clearTimeout(timer)
      clearInterval(poll)
      window.removeEventListener('focus', schedule)
      if (channel) void supabase.removeChannel(channel).catch(() => {})
    }
  }, [tableKey, channelId, reload])

  const current = state.source === loader ? state : { data: null, loading: true, refreshing: true, error: null }
  return { ...current, reload, realtimeWarning: realtime.key === tableKey && realtime.warning }
}
