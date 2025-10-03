/**
 * App Check Middleware for HTTP Functions
 * 
 * Lightweight wrapper to require App Check header for HTTP endpoints.
 * 
 * NOTE: For callable functions, use `enforceAppCheck: true` in runWith config instead.
 * This middleware is for HTTP functions (onRequest) where you need manual validation.
 * 
 * Usage:
 * ```typescript
 * import { requireAppCheck } from './middleware/appCheck';
 * 
 * export const myHttpEndpoint = functions.https.onRequest(
 *   requireAppCheck(async (req, res) => {
 *     // Your handler logic here
 *     res.status(200).send({ success: true });
 *   })
 * );
 * ```
 */

import type {Request, Response} from 'firebase-functions/v1';

type HttpHandler = (req: Request, res: Response) => void | Promise<void>;

export const requireAppCheck = (handler: HttpHandler): HttpHandler => {
  return (req: Request, res: Response) => {
    // Check for X-Firebase-AppCheck header
    const token = req.header('X-Firebase-AppCheck');
    
    if (!token) {
      res.status(401).send('App Check required');
      return;
    }
    
    // TODO: Optionally verify token using Firebase Admin SDK
    // For now, just check presence. Full verification can be added:
    // const appCheck = admin.appCheck();
    // await appCheck.verifyToken(token);
    
    return handler(req, res);
  };
};
