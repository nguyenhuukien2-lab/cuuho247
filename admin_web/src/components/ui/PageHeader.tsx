import type { ReactNode } from 'react'
export function PageHeader({ eyebrow, title, description, actions }: { eyebrow?: string; title: string; description?: string; actions?: ReactNode }) {
  return <header className="page-header"><div><div className="eyebrow">{eyebrow ?? 'ĐIỀU HÀNH / TRUNG TÂM CỨU HỘ'}</div><h1>{title}</h1>{description && <p>{description}</p>}</div>{actions && <div className="header-actions">{actions}</div>}</header>
}
