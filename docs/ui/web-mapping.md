# Web Mapping - Next.js Implementation Guide

> **Purpose**: Map Flutter mobile design system to Next.js web equivalents
>
> **Status**: Documentation Only - No Implementation Yet
>
> **Last Updated**: 2025-10-03
>
> **Target**: Future web implementation after mobile is complete

---

## Overview

This document provides a mapping between the Flutter mobile design system and Next.js web equivalents. The goal is to maintain visual and functional consistency across platforms while leveraging web-specific optimizations.

**Priority**: Mobile-first. Web implementation should only begin after mobile UI is complete and stable.

---

## Design Tokens Mapping

### Flutter → Next.js (CSS Variables)

```css
/* lib/design/tokens.dart → styles/tokens.css */

:root {
  /* Brand Colors */
  --color-sierra-blue: #1976D2;
  --color-painting-orange: #FF9800;
  
  /* Semantic Colors */
  --color-success-green: #4CAF50;
  --color-warning-amber: #FFA726;
  --color-error-red: #D32F2F;
  --color-info-blue: #2196F3;
  
  /* Spacing Scale */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;
  --space-xxl: 48px;
  
  /* Border Radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-full: 9999px;
  
  /* Elevation (Box Shadow) */
  --elevation-0: none;
  --elevation-1: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24);
  --elevation-2: 0 3px 6px rgba(0,0,0,0.16), 0 3px 6px rgba(0,0,0,0.23);
  --elevation-3: 0 10px 20px rgba(0,0,0,0.19), 0 6px 6px rgba(0,0,0,0.23);
  --elevation-4: 0 14px 28px rgba(0,0,0,0.25), 0 10px 10px rgba(0,0,0,0.22);
  
  /* Motion Durations */
  --motion-xfast: 100ms;
  --motion-fast: 150ms;
  --motion-medium: 200ms;
  --motion-slow: 300ms;
  --motion-xslow: 500ms;
  
  /* Touch Targets (replaced by clickable areas on web) */
  --touch-target-min: 44px;
  --touch-target-comfortable: 48px;
  --touch-target-large: 56px;
}

/* Dark theme */
[data-theme='dark'] {
  --color-surface: #121212;
  --color-surface-elevation-1: #1E1E1E;
  --color-surface-elevation-2: #2A2A2A;
  --color-surface-elevation-3: #363636;
}
```

### Using Tokens with Tailwind CSS

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        'sierra-blue': '#1976D2',
        'painting-orange': '#FF9800',
        'success-green': '#4CAF50',
        'warning-amber': '#FFA726',
        'error-red': '#D32F2F',
        'info-blue': '#2196F3',
      },
      spacing: {
        'xs': '4px',
        'sm': '8px',
        'md': '16px',
        'lg': '24px',
        'xl': '32px',
        'xxl': '48px',
      },
      borderRadius: {
        'sm': '4px',
        'md': '8px',
        'lg': '12px',
        'xl': '16px',
      },
      transitionDuration: {
        'xfast': '100ms',
        'fast': '150ms',
        'medium': '200ms',
        'slow': '300ms',
        'xslow': '500ms',
      },
    },
  },
}
```

---

## Component Mapping

### AppButton → Button Component

**Flutter:** `lib/design/components/app_button.dart`

**Next.js:** `components/ui/button.tsx`

```tsx
// components/ui/button.tsx
interface ButtonProps {
  label: string;
  onClick?: () => void;
  icon?: React.ReactNode;
  loading?: boolean;
  variant?: 'filled' | 'outlined' | 'text';
  disabled?: boolean;
}

export function Button({ 
  label, 
  onClick, 
  icon, 
  loading, 
  variant = 'filled',
  disabled 
}: ButtonProps) {
  const baseClasses = "px-lg py-md rounded-md transition-all duration-medium";
  const variantClasses = {
    filled: "bg-sierra-blue text-white hover:bg-opacity-90",
    outlined: "border-2 border-sierra-blue text-sierra-blue hover:bg-sierra-blue hover:bg-opacity-10",
    text: "text-sierra-blue hover:bg-sierra-blue hover:bg-opacity-10",
  };
  
  return (
    <button
      onClick={onClick}
      disabled={disabled || loading}
      className={`${baseClasses} ${variantClasses[variant]}`}
    >
      {loading ? <Spinner /> : (
        <>
          {icon && <span className="mr-sm">{icon}</span>}
          {label}
        </>
      )}
    </button>
  );
}
```

### AppInput → Input Component

**Flutter:** `lib/design/components/app_input.dart`

**Next.js:** `components/ui/input.tsx`

```tsx
// components/ui/input.tsx
interface InputProps {
  label?: string;
  value: string;
  onChange: (value: string) => void;
  type?: 'text' | 'email' | 'password' | 'number';
  error?: string;
  prefixIcon?: React.ReactNode;
  disabled?: boolean;
}

export function Input({
  label,
  value,
  onChange,
  type = 'text',
  error,
  prefixIcon,
  disabled
}: InputProps) {
  return (
    <div className="flex flex-col gap-xs">
      {label && <label className="text-sm font-medium">{label}</label>}
      <div className="relative">
        {prefixIcon && (
          <span className="absolute left-md top-1/2 -translate-y-1/2">
            {prefixIcon}
          </span>
        )}
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          disabled={disabled}
          className={`
            w-full px-md py-md rounded-md border
            ${prefixIcon ? 'pl-12' : ''}
            ${error ? 'border-error-red' : 'border-gray-300'}
            focus:outline-none focus:ring-2 focus:ring-sierra-blue
            transition-all duration-fast
          `}
        />
      </div>
      {error && <span className="text-sm text-error-red">{error}</span>}
    </div>
  );
}
```

### AppCard → Card Component

**Flutter:** `lib/design/components/app_card.dart`

**Next.js:** `components/ui/card.tsx`

```tsx
// components/ui/card.tsx
interface CardProps {
  children: React.ReactNode;
  onClick?: () => void;
  className?: string;
}

export function Card({ children, onClick, className }: CardProps) {
  const Component = onClick ? 'button' : 'div';
  
  return (
    <Component
      onClick={onClick}
      className={`
        bg-white rounded-lg shadow-elevation-1
        p-md hover:shadow-elevation-2
        transition-shadow duration-medium
        ${onClick ? 'cursor-pointer' : ''}
        ${className}
      `}
    >
      {children}
    </Component>
  );
}
```

### AppEmpty → EmptyState Component

**Flutter:** `lib/design/components/app_empty.dart`

**Next.js:** `components/ui/empty-state.tsx`

```tsx
// components/ui/empty-state.tsx
interface EmptyStateProps {
  icon: React.ReactNode;
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
}

export function EmptyState({
  icon,
  title,
  description,
  actionLabel,
  onAction
}: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center p-xl text-center">
      <div className="text-sierra-blue opacity-30 mb-lg">
        {icon}
      </div>
      <h3 className="text-2xl font-semibold mb-sm">{title}</h3>
      <p className="text-gray-600 mb-xl">{description}</p>
      {actionLabel && onAction && (
        <Button label={actionLabel} onClick={onAction} icon={<PlusIcon />} />
      )}
    </div>
  );
}
```

### AppSkeleton → Skeleton Component

**Flutter:** `lib/design/components/app_skeleton.dart`

**Next.js:** `components/ui/skeleton.tsx`

```tsx
// components/ui/skeleton.tsx
interface SkeletonProps {
  width?: string | number;
  height?: string | number;
  variant?: 'text' | 'circular' | 'rectangular';
  className?: string;
}

export function Skeleton({
  width = '100%',
  height = '16px',
  variant = 'text',
  className
}: SkeletonProps) {
  const variantClasses = {
    text: 'rounded-sm',
    circular: 'rounded-full',
    rectangular: 'rounded-lg',
  };
  
  return (
    <div
      className={`
        bg-gray-200 animate-pulse
        ${variantClasses[variant]}
        ${className}
      `}
      style={{ width, height }}
    />
  );
}
```

### AppBadge → Badge Component

**Flutter:** `lib/design/components/app_badge.dart`

**Next.js:** `components/ui/badge.tsx`

```tsx
// components/ui/badge.tsx
interface BadgeProps {
  label: string;
  variant?: 'neutral' | 'success' | 'warning' | 'error' | 'info';
  icon?: React.ReactNode;
}

export function Badge({ label, variant = 'neutral', icon }: BadgeProps) {
  const variantClasses = {
    neutral: 'bg-gray-200 text-gray-800',
    success: 'bg-success-green text-white',
    warning: 'bg-warning-amber text-gray-900',
    error: 'bg-error-red text-white',
    info: 'bg-info-blue text-white',
  };
  
  return (
    <span
      className={`
        inline-flex items-center gap-xs
        px-md py-xs rounded-full text-xs font-medium
        ${variantClasses[variant]}
      `}
    >
      {icon && <span className="w-4 h-4">{icon}</span>}
      {label}
    </span>
  );
}
```

---

## Theme System Mapping

### Flutter Theme → Next.js Theme Provider

**Flutter:** `lib/design/theme.dart`

**Next.js:** `lib/theme-provider.tsx`

```tsx
// lib/theme-provider.tsx
import { createContext, useContext, useEffect, useState } from 'react';

type Theme = 'light' | 'dark' | 'system';

const ThemeContext = createContext<{
  theme: Theme;
  setTheme: (theme: Theme) => void;
}>({
  theme: 'system',
  setTheme: () => null,
});

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>('system');
  
  useEffect(() => {
    // Apply theme to document
    const root = window.document.documentElement;
    const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches
      ? 'dark'
      : 'light';
    const appliedTheme = theme === 'system' ? systemTheme : theme;
    
    root.dataset.theme = appliedTheme;
  }, [theme]);
  
  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);
```

---

## Image Optimization

### Flutter → Next.js Image

**Flutter:** Native Image widget with caching

**Next.js:** Next.js Image component

```tsx
// Flutter equivalent: CachedNetworkImage
import Image from 'next/image';

<Image
  src="/path/to/image.jpg"
  alt="Description"
  width={200}
  height={200}
  placeholder="blur"
  blurDataURL="/path/to/placeholder.jpg"
/>
```

---

## Data Fetching Patterns

### Flutter Riverpod → Next.js SWR/React Query

**Flutter:** `ref.watch(dataProvider)`

**Next.js:** `useSWR` or `useQuery`

```tsx
// With SWR
import useSWR from 'swr';

function InvoicesScreen() {
  const { data, error, mutate } = useSWR('/api/invoices', fetcher);
  
  if (error) return <EmptyState icon={<ErrorIcon />} title="Error loading invoices" />;
  if (!data) return <Skeleton variant="rectangular" height={120} />;
  
  return (
    <div>
      {data.map(invoice => (
        <Card key={invoice.id}>{/* Invoice content */}</Card>
      ))}
    </div>
  );
}
```

---

## Motion & Animation

### Flutter AnimatedOpacity → Framer Motion

**Flutter:** `AnimatedOpacity` with MotionUtils

**Next.js:** Framer Motion

```tsx
import { motion } from 'framer-motion';

<motion.div
  initial={{ opacity: 0 }}
  animate={{ opacity: 1 }}
  transition={{ duration: 0.2 }}
>
  Content
</motion.div>
```

### Respecting prefers-reduced-motion

```tsx
// hooks/use-motion-preference.ts
export function useMotionPreference() {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);
  
  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    setPrefersReducedMotion(mediaQuery.matches);
    
    const handler = () => setPrefersReducedMotion(mediaQuery.matches);
    mediaQuery.addEventListener('change', handler);
    return () => mediaQuery.removeEventListener('change', handler);
  }, []);
  
  return prefersReducedMotion;
}

// Usage
const prefersReducedMotion = useMotionPreference();
const duration = prefersReducedMotion ? 0 : 0.2;
```

---

## Page Layouts to Port

### Screen Mapping

| Flutter Screen | Next.js Page | Route | Priority |
|----------------|-------------|-------|----------|
| `LoginScreen` | `app/login/page.tsx` | `/login` | P0 |
| `TimeclockScreen` | `app/timeclock/page.tsx` | `/timeclock` | P0 |
| `InvoicesScreen` | `app/invoices/page.tsx` | `/invoices` | P1 |
| `EstimatesScreen` | `app/estimates/page.tsx` | `/estimates` | P1 |
| `AdminScreen` | `app/admin/page.tsx` | `/admin` | P2 |

### Layout Structure

```
app/
├── layout.tsx          # Root layout with ThemeProvider
├── login/
│   └── page.tsx       # Public route
├── (authenticated)/   # Route group with auth middleware
│   ├── layout.tsx     # Authenticated layout with nav
│   ├── timeclock/
│   │   └── page.tsx
│   ├── invoices/
│   │   └── page.tsx
│   ├── estimates/
│   │   └── page.tsx
│   └── admin/
│       └── page.tsx
└── error.tsx          # Error boundary
```

---

## Font System

### Flutter → Next.js

**Flutter:** System fonts (Roboto on Android, San Francisco on iOS)

**Next.js:** Next.js Font Optimization

```tsx
// app/layout.tsx
import { Inter } from 'next/font/google';

const inter = Inter({ subsets: ['latin'] });

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={inter.className}>
      <body>{children}</body>
    </html>
  );
}
```

---

## State Management

### Riverpod → Zustand/Redux

**Flutter:** Riverpod providers

**Next.js:** Zustand (simpler) or Redux Toolkit

```tsx
// store/auth-store.ts (Zustand)
import create from 'zustand';

interface AuthState {
  user: User | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  signIn: async (email, password) => {
    // Firebase auth logic
    const user = await signInWithEmailAndPassword(auth, email, password);
    set({ user: user.user });
  },
  signOut: async () => {
    await signOut(auth);
    set({ user: null });
  },
}));
```

---

## Accessibility

### Screen Reader Support

**Flutter:** Semantics widgets

**Next.js:** ARIA attributes

```tsx
// Accessible button
<button
  aria-label="Create new invoice"
  aria-describedby="invoice-description"
>
  <PlusIcon />
</button>

// Accessible form
<form aria-labelledby="login-form-title">
  <h2 id="login-form-title">Sign In</h2>
  <Input label="Email" aria-required="true" />
</form>
```

---

## Implementation Priority

### Phase 1: Core Infrastructure (Weeks 1-2)
- [ ] Set up Next.js project structure
- [ ] Create design tokens (CSS variables)
- [ ] Build core components (Button, Input, Card)
- [ ] Set up theme provider
- [ ] Configure Tailwind CSS

### Phase 2: Authentication & Layout (Weeks 3-4)
- [ ] Implement Firebase auth
- [ ] Build layout components (Nav, Header)
- [ ] Create login page
- [ ] Set up route guards

### Phase 3: Core Screens (Weeks 5-8)
- [ ] Timeclock screen
- [ ] Invoices screen
- [ ] Estimates screen
- [ ] Admin screen

### Phase 4: Polish & Testing (Weeks 9-10)
- [ ] Accessibility audit
- [ ] Performance optimization
- [ ] Cross-browser testing
- [ ] Mobile responsive testing

---

## Performance Considerations

### Web-Specific Optimizations

1. **Code Splitting**: Use dynamic imports for heavy components
2. **Image Optimization**: Next.js Image component with proper sizing
3. **Font Optimization**: Next.js Font with preloading
4. **Caching**: SWR for stale-while-revalidate pattern
5. **Bundle Size**: Tree-shaking and code splitting
6. **Hydration**: Avoid hydration mismatches
7. **Lighthouse Score**: Target 90+ on all metrics

---

## Conclusion

This mapping provides a clear path from Flutter mobile to Next.js web while maintaining design consistency and performance. Mobile implementation must be complete and stable before starting web development.

**Next Steps:**
1. Complete mobile UI overhaul (PR-01 through PR-06)
2. Gather metrics and user feedback
3. Refine design tokens based on learnings
4. Begin web implementation following this mapping

---

**Last Updated**: 2025-10-03  
**Author**: Development Team  
**Status**: Documentation Complete - Ready for Future Implementation
