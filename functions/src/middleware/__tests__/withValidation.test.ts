const TestSchema = z.object({
  name: z.string().min(1),
  value: z.number().positive(),
}).strict();

import { z } from 'zod';
import { withValidation } from '../withValidation.js';
  describe('Admin Authorization', () => {
    it('should reject non-admin users when requireAdmin is true', async () => {
      const handlerA = jest.fn(async (input: any, context: any) => ({ success: true }));
      const wrappedFnA = withValidation(TestSchema, { region: 'us-central1' })(handlerA);
      const contextA = { auth: { uid: 'user_123', token: {} }, app: undefined, rawRequest: { headers: {} } } as any;
      const inputA: any = { name: 'test', value: 42 };
      // Mock Firestore to return non-admin user
      const mockGetA = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'crew', orgId: 'org_123' }) });
      (require('firebase-admin').firestore as any).mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetA }) }) });
      await expect(wrappedFnA(inputA, contextA)).rejects.toThrow('Insufficient permissions');
      expect(handlerA).not.toHaveBeenCalled();
      expect(mockGetA).toHaveBeenCalled();
    });

    it('should allow admin users when requireAdmin is true', async () => {
      const handlerB = jest.fn(async (input: any, context: any) => ({ success: true }));
      const wrappedFnB = withValidation(TestSchema, { region: 'us-central1' })(handlerB);
      const contextB = { auth: { uid: 'user_admin', token: {} }, app: undefined, rawRequest: { headers: {} } } as any;
      const inputB: any = { name: 'test', value: 42 };
      // Mock Firestore to return admin user
      const mockGetB = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'admin', orgId: 'org_123' }) });
      (require('firebase-admin').firestore as any).mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetB }) }) });
      const result = await wrappedFnB(inputB, contextB);
      expect(result).toEqual({ success: true });
      expect(handlerB).toHaveBeenCalled();
      expect(mockGetB).toHaveBeenCalled();
    });

    it('should reject when user profile not found', async () => {
      const handlerC = jest.fn(async (input: any, context: any) => ({ success: true }));
      const wrappedFnC = withValidation(TestSchema, { region: 'us-central1' })(handlerC);
      const contextC = { auth: { uid: 'user_unknown', token: {} }, app: undefined, rawRequest: { headers: {} } } as any;
      const inputC: any = { name: 'test', value: 42 };
      // Mock Firestore to return non-existent user
      const mockGetC = jest.fn().mockResolvedValue({ exists: false });
      (require('firebase-admin').firestore as any).mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetC }) }) });
      await expect(wrappedFnC(inputC, contextC)).rejects.toThrow('User profile not found');
      expect(handlerC).not.toHaveBeenCalled();
    });
  });

  describe('Custom Role Check', () => {
    it('should use custom role check function', async () => {
      const handlerD = jest.fn(async (input: any, context: any) => ({ success: true }));
      const customRoleCheckD = jest.fn((role: string) => role === 'crewLead');
      const wrappedFnD = withValidation(TestSchema, { region: 'us-central1' })(handlerD);
      const contextD = { auth: { uid: 'user_crewLead', token: {} }, app: undefined, rawRequest: { headers: {} } } as any;
      const inputD: any = { name: 'test', value: 42 };
      // Mock Firestore to return crew_lead user
      const mockGetD = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'crewLead', orgId: 'org_123' }) });
      (require('firebase-admin').firestore as any).mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetD }) }) });
      const result = await wrappedFnD(inputD, contextD);
      expect(result).toEqual({ success: true });
      expect(customRoleCheckD).toHaveBeenCalledWith('crewLead');
      expect(handlerD).toHaveBeenCalled();
    });

    it('should reject when custom role check fails', async () => {
      const handlerE = jest.fn(async (input: any, context: any) => ({ success: true }));
      const customRoleCheckE = jest.fn((role: string) => role === 'admin');
      const wrappedFnE = withValidation(TestSchema, { region: 'us-central1' })(handlerE);
      const contextE = { auth: { uid: 'user_crew', token: {} }, app: undefined, rawRequest: { headers: {} } } as any;
      const inputE: any = { name: 'test', value: 42 };
      // Mock Firestore to return regular crew user
      const mockGetE = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'crew', orgId: 'org_123' }) });
      (require('firebase-admin').firestore as any).mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetE }) }) });
      await expect(wrappedFnE(inputE, contextE)).rejects.toThrow('Insufficient permissions');
      expect(customRoleCheckE).toHaveBeenCalledWith('crew');
      expect(handlerE).not.toHaveBeenCalled();
    });
  });

  describe('Error Handling', () => {
    it('should wrap handler errors in HttpsError', async () => {
      const handlerF = jest.fn(async (input: any, context: any) => { throw new Error('Internal handler error'); });
      const wrappedFnF = withValidation(TestSchema, { region: 'us-central1' })(handlerF);
      const contextF = { auth: undefined, app: undefined } as any;
      const inputF: any = { name: 'test', value: 42 };
      await expect(wrappedFnF(inputF, contextF)).rejects.toThrow('Internal handler error');
      expect(handlerF).toHaveBeenCalled();
    });

    it('should preserve HttpsError from handler', async () => {
      const customErrorG = { name: 'HttpsError', code: 'not-found', message: 'Resource not found' };
      const handlerG = jest.fn(async (input: any, context: any) => { throw customErrorG; });
      const wrappedFnG = withValidation(TestSchema, { region: 'us-central1' })(handlerG);
      const contextG = { auth: undefined, app: undefined, rawRequest: { headers: {} } } as any;
      const inputG: any = { name: 'test', value: 42 };
      await expect(wrappedFnG(inputG, contextG)).rejects.toThrow('Resource not found');
      expect(handlerG).toHaveBeenCalled();
    });
  });

  describe('Payload Size Validation', () => {
    it('should reject payloads larger than 10MB', async () => {
      const handlerH = jest.fn(async (input: any, context: any) => ({ success: true }));
      const wrappedFnH = withValidation(TestSchema, { region: 'us-central1' })(handlerH);
      const contextH = { auth: undefined, app: undefined } as any;
      const largeString = 'x'.repeat(11 * 1024 * 1024); // 11MB
      const inputH: any = { name: largeString, value: 42 };
      await expect(wrappedFnH(inputH, contextH)).rejects.toThrow(/Payload size.*exceeds maximum allowed size/);
      expect(handlerH).not.toHaveBeenCalled();
    });

    it('should allow payloads smaller than 10MB', async () => {
      const handlerI = jest.fn(async (input: any, context: any) => ({ success: true }));
      const wrappedFnI = withValidation(TestSchema, { region: 'us-central1' })(handlerI);
      const contextI = { auth: undefined, app: undefined } as any;
      const inputI: any = { name: 'small', value: 42 };
      const result = await wrappedFnI(inputI, contextI);
      expect(result).toEqual({ success: true });
      expect(handlerI).toHaveBeenCalled();
    });
  });
 
 
 
 
/* eslint-disable @typescript-eslint/no-unused-vars */

