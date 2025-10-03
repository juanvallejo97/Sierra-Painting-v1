/**
 * Web App Home Page
 * 
 * Landing page for the web application.
 * Redirects to login if not authenticated, or shows dashboard if authenticated.
 */

import { getUser } from '@/lib/auth/server';
import { redirect } from 'next/navigation';

// Mark this page as dynamic (uses cookies)
export const dynamic = 'force-dynamic';

export default async function HomePage() {
  const user = await getUser();

  // If authenticated, redirect to timeclock (main app)
  if (user) {
    redirect('/web/timeclock');
  }

  // If not authenticated, redirect to login
  redirect('/web/login');
}

