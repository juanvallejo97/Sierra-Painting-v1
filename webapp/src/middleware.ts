/**
 * Next.js Middleware
 * 
 * Runs on every request before the route handler.
 * Used for:
 * - Session management
 * - Protected routes
 * - Request logging
 * - Security headers
 */

import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

/**
 * Protected routes that require authentication
 */
const PROTECTED_ROUTES = [
  '/web/timeclock',
  '/web/invoices',
  '/web/estimates',
  '/web/admin',
];

/**
 * Public routes (no auth required)
 */
const PUBLIC_ROUTES = ['/web/login', '/web/signup', '/web/forgot-password'];

/**
 * Check if path matches a pattern
 */
function matchesRoute(path: string, routes: string[]): boolean {
  return routes.some((route) => {
    if (route.endsWith('*')) {
      return path.startsWith(route.slice(0, -1));
    }
    return path === route || path.startsWith(route + '/');
  });
}

/**
 * Middleware function
 */
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Only process /web/* routes
  if (!pathname.startsWith('/web')) {
    return NextResponse.next();
  }

  // Get session token from cookie
  const sessionToken = request.cookies.get('__session')?.value;

  // Check if route requires authentication
  const isProtectedRoute = matchesRoute(pathname, PROTECTED_ROUTES);
  const isPublicRoute = matchesRoute(pathname, PUBLIC_ROUTES);

  // Redirect to login if accessing protected route without session
  if (isProtectedRoute && !sessionToken) {
    const loginUrl = new URL('/web/login', request.url);
    loginUrl.searchParams.set('redirect', pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Redirect to home if accessing public route with active session
  if (isPublicRoute && sessionToken) {
    return NextResponse.redirect(new URL('/web', request.url));
  }

  // Note: We can't verify token or check roles in Edge Middleware
  // Role checking happens in Server Components using auth helpers
  // This is just a lightweight check to redirect unauthorized users early

  // Continue with request
  const response = NextResponse.next();

  // Add security headers
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');

  // Add request ID for tracing
  const requestId = crypto.randomUUID();
  response.headers.set('X-Request-ID', requestId);

  return response;
}

/**
 * Middleware configuration
 * Only run on /web/* routes
 */
export const config = {
  matcher: [
    /*
     * Match all request paths under /web except:
     * - _next/static (static files)
     * - _next/image (image optimization)
     * - favicon.ico (favicon)
     */
    '/web/((?!_next/static|_next/image|favicon.ico).*)',
  ],
};
