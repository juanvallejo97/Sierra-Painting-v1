import { z } from 'zod';
// Mock firebase-admin Firestore
jest.mock('firebase-admin', () => ({
    firestore: jest.fn(),
}));
const TestSchema = z.object({
    name: z.string().min(1),
    value: z.number().positive(),
}).strict();
import { withValidation } from '../withValidation.js';
describe('Admin Authorization', () => {
    it('should reject non-admin users when requireAdmin is true', async () => {
        const handlerA = jest.fn(async (_input, _context) => ({ success: true }));
        const _wrappedFnA1 = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerA);
        const wrappedFnA = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerA);
        const contextA = { auth: { uid: 'user_123', token: {} }, app: undefined, rawRequest: { headers: {} } };
        const inputA = { name: 'test', value: 42 };
        // Mock Firestore to return non-admin user
        const mockGetA = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'crew', orgId: 'org_123' }) });
        require('firebase-admin').firestore.mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetA }) }) });
        await expect(wrappedFnA(inputA, contextA)).rejects.toThrow('Insufficient permissions');
        expect(handlerA).not.toHaveBeenCalled();
        expect(mockGetA).toHaveBeenCalled();
    });
    it('should allow admin users when requireAdmin is true', async () => {
        const handlerB = jest.fn(async (_input, _context) => ({ success: true }));
        const _wrappedFnB1 = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerB);
        const wrappedFnB = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerB);
        const contextB = { auth: { uid: 'user_admin', token: {} }, app: undefined, rawRequest: { headers: {} } };
        const inputB = { name: 'test', value: 42 };
        // Mock Firestore to return admin user
        const mockGetB = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'admin', orgId: 'org_123' }) });
        require('firebase-admin').firestore.mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetB }) }) });
        const result = await wrappedFnB(inputB, contextB);
        expect(result).toEqual({ success: true });
        expect(handlerB).toHaveBeenCalled();
        expect(mockGetB).toHaveBeenCalled();
    });
    it('should reject when user profile not found', async () => {
        const handlerC = jest.fn(async (_input, _context) => ({ success: true }));
        const _wrappedFnC1 = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerC);
        const wrappedFnC = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerC);
        const contextC = { auth: { uid: 'user_unknown', token: {} }, app: undefined, rawRequest: { headers: {} } };
        const inputC = { name: 'test', value: 42 };
        // Mock Firestore to return non-existent user
        const mockGetC = jest.fn().mockResolvedValue({ exists: false });
        require('firebase-admin').firestore.mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetC }) }) });
        await expect(wrappedFnC(inputC, contextC)).rejects.toThrow('User profile not found');
        expect(handlerC).not.toHaveBeenCalled();
    });
});
describe('Custom Role Check', () => {
    it('should use custom role check function', async () => {
        const handlerD = jest.fn(async (_input, _context) => ({ success: true }));
        const customRoleCheckD = jest.fn((role) => role === 'crewLead');
        const _wrappedFnD1 = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true, customRoleCheck: customRoleCheckD })(handlerD);
        const wrappedFnD = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true, customRoleCheck: customRoleCheckD })(handlerD);
        const contextD = { auth: { uid: 'user_crewLead', token: {} }, app: undefined, rawRequest: { headers: {} } };
        const inputD = { name: 'test', value: 42 };
        // Mock Firestore to return crew_lead user
        const mockGetD = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'crewLead', orgId: 'org_123' }) });
        require('firebase-admin').firestore.mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetD }) }) });
        const result = await wrappedFnD(inputD, contextD);
        expect(result).toEqual({ success: true });
        expect(customRoleCheckD).toHaveBeenCalledWith('crewLead');
        expect(handlerD).toHaveBeenCalled();
    });
    it('should reject when custom role check fails', async () => {
        const handlerE = jest.fn(async (_input, _context) => ({ success: true }));
        const customRoleCheckE = jest.fn((role) => role === 'admin');
        const _wrappedFnE1 = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true, customRoleCheck: customRoleCheckE })(handlerE);
        const wrappedFnE = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true, customRoleCheck: customRoleCheckE })(handlerE);
        const contextE = { auth: { uid: 'user_crew', token: {} }, app: undefined, rawRequest: { headers: {} } };
        const inputE = { name: 'test', value: 42 };
        // Mock Firestore to return regular crew user
        const mockGetE = jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: 'crew', orgId: 'org_123' }) });
        require('firebase-admin').firestore.mockReturnValue({ collection: () => ({ doc: () => ({ get: mockGetE }) }) });
        await expect(wrappedFnE(inputE, contextE)).rejects.toThrow('Insufficient permissions');
        expect(customRoleCheckE).toHaveBeenCalledWith('crew');
        expect(handlerE).not.toHaveBeenCalled();
    });
});
describe('Error Handling', () => {
    it('should wrap handler errors in HttpsError', async () => {
        const handlerF = jest.fn(async (_input, _context) => { throw new Error('Internal handler error'); });
        const _wrappedFnF1 = withValidation(TestSchema, { region: 'us-east4' })(handlerF);
        const wrappedFnF = withValidation(TestSchema, { region: 'us-east4' })(handlerF);
        const contextF = { auth: undefined, app: undefined };
        const inputF = { name: 'test', value: 42 };
        await expect(wrappedFnF(inputF, contextF)).rejects.toThrow('Internal handler error');
        expect(handlerF).toHaveBeenCalled();
    });
    it('should preserve HttpsError from handler', async () => {
        const customErrorG = { name: 'HttpsError', code: 'not-found', message: 'Resource not found' };
        const handlerG = jest.fn(async (_input, _context) => { throw customErrorG; });
        const _wrappedFnG1 = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerG);
        const wrappedFnG = withValidation(TestSchema, { region: 'us-east4', requireAdmin: true })(handlerG);
        const contextG = { auth: undefined, app: undefined, rawRequest: { headers: {} } };
        const inputG = { name: 'test', value: 42 };
        await expect(wrappedFnG(inputG, contextG)).rejects.toThrow('Insufficient permissions');
        expect(handlerG).not.toHaveBeenCalled();
    });
});
describe('Payload Size Validation', () => {
    it('should reject payloads larger than 10MiB', async () => {
        const handlerH = jest.fn(async (_input, _context) => ({ success: true }));
        const _wrappedFnH1 = withValidation(TestSchema, { region: 'us-east4' })(handlerH);
        const wrappedFnH = withValidation(TestSchema, { region: 'us-east4' })(handlerH);
        const contextH = { auth: undefined, app: undefined };
        const largeString = 'x'.repeat(11 * 1024 * 1024); // 11MiB
        const inputH = { name: largeString, value: 42 };
        await expect(wrappedFnH(inputH, contextH)).rejects.toThrow(/Payload size.*exceeds maximum allowed size/);
        expect(handlerH).not.toHaveBeenCalled();
    });
    it('should allow payloads smaller than 10MiB', async () => {
        const handlerI = jest.fn(async (_input, _context) => ({ success: true }));
        const _wrappedFnI1 = withValidation(TestSchema, { region: 'us-east4' })(handlerI);
        const wrappedFnI = withValidation(TestSchema, { region: 'us-east4' })(handlerI);
        const contextI = { auth: undefined, app: undefined };
        const inputI = { name: 'small', value: 42 };
        const result = await wrappedFnI(inputI, contextI);
        expect(result).toEqual({ success: true });
        expect(handlerI).toHaveBeenCalled();
    });
});
