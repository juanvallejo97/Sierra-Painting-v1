/**
 * Client-side auth actions
 * 
 * React hooks and utilities for authentication in client components.
 * Uses Firebase Auth SDK for client-side authentication.
 * 
 * Usage:
 *   import { useAuth } from '@/lib/auth/client';
 *   const { user, loading, signIn, signOut } = useAuth();
 */

'use client';

import { useEffect, useState } from 'react';
import {
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  User as FirebaseUser,
} from 'firebase/auth';
import { auth, getFirebaseErrorMessage } from '@/lib/firebase/client';

/**
 * Auth hook return type
 */
export interface UseAuthReturn {
  user: FirebaseUser | null;
  loading: boolean;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

/**
 * React hook for authentication
 * 
 * Provides current user state and auth actions.
 * Automatically updates when auth state changes.
 * 
 * @returns Auth state and actions
 */
export function useAuth(): UseAuthReturn {
  const [user, setUser] = useState<FirebaseUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Subscribe to auth state changes
    const unsubscribe = onAuthStateChanged(
      auth,
      (firebaseUser) => {
        setUser(firebaseUser);
        setLoading(false);
        setError(null);
      },
      (error) => {
        console.error('Auth state change error:', error);
        setError(getFirebaseErrorMessage(error));
        setLoading(false);
      }
    );

    // Cleanup subscription
    return () => unsubscribe();
  }, []);

  /**
   * Sign in with email and password
   */
  const signIn = async (email: string, password: string) => {
    try {
      setError(null);
      setLoading(true);

      const userCredential = await signInWithEmailAndPassword(auth, email, password);

      // Get ID token and set as cookie
      const idToken = await userCredential.user.getIdToken();
      
      // Call API route to set session cookie
      const response = await fetch('/web/api/auth/session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ idToken }),
      });

      if (!response.ok) {
        throw new Error('Failed to create session');
      }

      setUser(userCredential.user);
    } catch (err) {
      const errorMessage = getFirebaseErrorMessage(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Sign out
   */
  const signOut = async () => {
    try {
      setError(null);
      setLoading(true);

      // Clear session cookie via API route
      await fetch('/web/api/auth/session', {
        method: 'DELETE',
      });

      // Sign out from Firebase
      await firebaseSignOut(auth);

      setUser(null);
    } catch (err) {
      const errorMessage = getFirebaseErrorMessage(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return {
    user,
    loading,
    error,
    signIn,
    signOut,
  };
}

/**
 * Check if user is authenticated
 * 
 * @returns true if user is authenticated
 */
export function useIsAuthenticated(): boolean {
  const { user, loading } = useAuth();
  return !loading && user !== null;
}
