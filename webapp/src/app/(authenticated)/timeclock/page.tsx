/**
 * Timeclock Page (Protected)
 * 
 * Example of a protected route that requires authentication.
 * Uses server-side auth verification.
 */

import { requireAuth } from '@/lib/auth/server';

// Mark this page as dynamic (uses cookies for auth)
export const dynamic = 'force-dynamic';

export default async function TimeclockPage() {
  // This runs on the server and enforces authentication
  const user = await requireAuth('/web/timeclock');

  return (
    <div>
      <h1 className="mb-6 text-3xl font-bold text-gray-900">⏰ Time Clock</h1>

      <div className="rounded-lg bg-white p-6 shadow">
        <div className="mb-4 rounded-lg bg-green-50 p-4">
          <p className="text-sm text-green-800">
            ✅ Authenticated as: <strong>{user.email}</strong>
          </p>
          <p className="mt-1 text-sm text-green-700">
            Role: <strong>{user.role}</strong>
          </p>
        </div>

        <p className="text-gray-600">
          This is a protected route. You can only see this page when logged in.
        </p>

        <div className="mt-6">
          <h2 className="mb-4 text-xl font-semibold text-gray-900">Clock In/Out</h2>
          <div className="space-y-4">
            <button className="rounded-lg bg-green-600 px-6 py-3 font-semibold text-white transition hover:bg-green-700">
              Clock In
            </button>
            <button className="ml-4 rounded-lg bg-red-600 px-6 py-3 font-semibold text-white transition hover:bg-red-700">
              Clock Out
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
