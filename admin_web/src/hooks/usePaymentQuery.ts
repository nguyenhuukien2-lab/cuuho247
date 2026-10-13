import { useCallback, useState } from 'react'
import type { ApiResult } from '../lib/adminTypes'
import type { PaymentCursor, PaymentFilters, PaymentQuery } from '../lib/paymentTypes'
import { useAdminData } from './useAdminData'
import { defaultPaymentFilters } from '../lib/paymentFormat'

// Server pagination boundary: no client-side totals or filtering of a partial page.
export function usePaymentQuery<T>(load: (query: PaymentQuery, signal?: AbortSignal) => Promise<ApiResult<T>>) {
  const [query, setQuery] = useState({ filters: defaultPaymentFilters, cursors: [null] as (PaymentCursor | null)[], page: 0 })
  const loader = useCallback((signal?: AbortSignal) => load({ ...query.filters, cursor: query.cursors[query.page], limit: 20 }, signal), [load, query])
  const resource = useAdminData(loader)
  const apply = (filters: PaymentFilters) => setQuery({ filters: { ...filters, search: filters.search.trim() }, cursors: [null], page: 0 })
  const next = (cursor: PaymentCursor | null | undefined) => {
    const key = JSON.stringify(cursor)
    if (resource.loading || resource.refreshing || resource.error || !cursor || query.cursors.slice(0, query.page + 1).some((value) => JSON.stringify(value) === key)) return
    setQuery({ ...query, cursors: [...query.cursors.slice(0, query.page + 1), cursor], page: query.page + 1 })
  }
  const previous = () => {
    if (!resource.loading && !resource.refreshing && query.page) setQuery({ ...query, page: query.page - 1 })
  }
  return { resource, filters: query.filters, page: query.page, apply, next, previous }
}
