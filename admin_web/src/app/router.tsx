import { Suspense } from 'react'
import { createBrowserRouter } from 'react-router-dom'
import { AdminRoute } from './AdminRoute'
import { DashboardPage, RescueRequestsPage, RescueRequestDetailPage, CustomersPage, CustomerDetailPage, RescuersPage, RescuerDetailPage, ServicesPage, QuotesPage, ReviewsPage, OperationsMapPage, NotificationsPage, SettingsPage, LoginPage, AuditLogsPage } from './lazyPages'
const page = (element: React.ReactNode) => <Suspense fallback={<div className="page-loading">Đang tải trang...</div>}>{element}</Suspense>
export const router = createBrowserRouter([
  { path: '/login', element: page(<LoginPage/>) },
  { path: '/', element: <AdminRoute/>, children: [
    { index: true, element: page(<DashboardPage/>) },
    { path: 'requests', element: page(<RescueRequestsPage/>) },
    { path: 'requests/:id', element: page(<RescueRequestDetailPage/>) },
    { path: 'customers', element: page(<CustomersPage/>) },
    { path: 'customers/:id', element: page(<CustomerDetailPage/>) },
    { path: 'rescuers', element: page(<RescuersPage/>) },
    { path: 'rescuers/:id', element: page(<RescuerDetailPage/>) },
    { path: 'services', element: page(<ServicesPage/>) },
    { path: 'quotes', element: page(<QuotesPage/>) },
    { path: 'reviews', element: page(<ReviewsPage/>) },
    { path: 'map', element: page(<OperationsMapPage/>) },
    { path: 'notifications', element: page(<NotificationsPage/>) },
    { path: 'audit-logs', element: page(<AuditLogsPage/>) },
    { path: 'settings', element: page(<SettingsPage/>) },
  ] },
])
