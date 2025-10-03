/**
 * Authenticated Layout
 * 
 * Layout for protected routes.
 * Includes navigation and user menu.
 */

import { ReactNode } from 'react';

export default function AuthenticatedLayout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation placeholder */}
      <nav className="border-b border-gray-200 bg-white">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            <div className="flex items-center">
              <h1 className="text-xl font-bold text-gray-900">🎨 Sierra Painting</h1>
            </div>
            <div>
              {/* User menu will go here */}
              <span className="text-sm text-gray-600">Web App</span>
            </div>
          </div>
        </div>
      </nav>

      {/* Main content */}
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">{children}</main>
    </div>
  );
}
