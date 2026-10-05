import { useState } from 'react'
import type { ApiResult, MutationResult } from '../lib/adminTypes'
import { ActionDialog } from '../components/ui/AdminAction'

export type AdminAction = { title: string; description: string; reason?: boolean; run: (reason: string) => Promise<ApiResult<MutationResult>> }
export function useAdminAction(reload: () => Promise<void>) {
  const [action, setAction] = useState<AdminAction | null>(null)
  const [notice, setNotice] = useState('')
  function open(next: AdminAction) { setNotice(''); setAction(next) }
  return {
    open,
    notice: notice ? <div className="data-success" role="status">{notice}</div> : null,
    dialog: action ? <ActionDialog action={action} onClose={() => setAction(null)} onSuccess={async (message) => {
      setAction(null)
      setNotice(message)
      await reload()
    }}/> : null,
  }
}
