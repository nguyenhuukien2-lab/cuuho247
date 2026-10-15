import { useLayoutEffect, useRef } from 'react'
import type { ReactNode } from 'react'
export function Confirmation({ title, busy, onClose, children }: { title: string; busy: boolean; onClose: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDialogElement>(null)
  useLayoutEffect(() => {
    const dialog = ref.current
    const previousFocus = document.activeElement as HTMLElement | null
    dialog?.showModal()
    return () => { dialog?.close(); previousFocus?.focus() }
  }, [])
  return <dialog ref={ref} className="system-dialog" aria-label={title} onCancel={(event) => { event.preventDefault(); if (!busy) onClose() }}>{children}</dialog>
}
