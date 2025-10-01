import {z} from "zod";

export const leadSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  phone: z.string().min(10),
  address: z.string().min(1),
  description: z.string().optional(),
  createdAt: z.date().optional(),
});

export const estimateSchema = z.object({
  leadId: z.string(),
  items: z.array(z.object({
    description: z.string(),
    quantity: z.number().positive(),
    unitPrice: z.number().positive(),
  })),
  laborHours: z.number().positive(),
  laborRate: z.number().positive(),
  notes: z.string().optional(),
});

export const markPaidManualSchema = z.object({
  invoiceId: z.string(),
  paymentMethod: z.enum(["check", "cash"]),
  amount: z.number().positive(),
  checkNumber: z.string().optional(),
  notes: z.string().optional(),
  paidAt: z.date().optional(),
});

export const stripeCheckoutSchema = z.object({
  invoiceId: z.string(),
  successUrl: z.string().url(),
  cancelUrl: z.string().url(),
});

export type Lead = z.infer<typeof leadSchema>;
export type Estimate = z.infer<typeof estimateSchema>;
export type MarkPaidManual = z.infer<typeof markPaidManualSchema>;
export type StripeCheckout = z.infer<typeof stripeCheckoutSchema>;
