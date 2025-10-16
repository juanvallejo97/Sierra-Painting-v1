/**
 * Generate Invoice PDF
 *
 * PURPOSE:
 * Create professional PDF invoices using PDFKit.
 * Generates PDFs with company branding, line items, totals, and payment instructions.
 *
 * FEATURES:
 * - Professional layout with company header
 * - Line items table with descriptions, quantities, unit prices, totals
 * - Subtotal, tax (if applicable), and grand total
 * - Payment instructions and due date
 * - Footer with company contact information
 * - Configurable styling (colors, fonts)
 *
 * USAGE:
 * const pdfBuffer = await generateInvoicePDF(invoiceData, companyData, customerData);
 * // Upload to Cloud Storage or return to client
 */

import PDFDocument from 'pdfkit';
import type PDFKit from 'pdfkit';
import * as admin from 'firebase-admin';

/**
 * Invoice data structure
 */
export interface InvoiceData {
  id?: string;
  companyId: string;
  customerId: string;
  jobId: string;
  status: string;
  amount: number;
  currency: string;
  items: InvoiceLineItem[];
  notes?: string;
  dueDate: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  taxRate?: number; // Optional: e.g., 0.08 for 8% sales tax
  pdfPath?: string; // Path to generated PDF in Cloud Storage
}

export interface InvoiceLineItem {
  description: string;
  quantity: number;
  unitPrice: number;
  discount?: number;
}

export interface CompanyData {
  id: string;
  name: string;
  address?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  phone?: string;
  email?: string;
  website?: string;
  logoUrl?: string; // Optional: URL to company logo
}

export interface CustomerData {
  id: string;
  name: string;
  address?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  email?: string;
  phone?: string;
}

/**
 * Generate PDF invoice
 *
 * @param invoice - Invoice data from Firestore
 * @param company - Company data
 * @param customer - Customer data
 * @returns Buffer containing PDF bytes
 */
export async function generateInvoicePDF(
  invoice: InvoiceData,
  company: CompanyData,
  customer: CustomerData
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    try {
      // Create PDF document
      const doc = new PDFDocument({
        size: 'A4',
        margin: 50,
        info: {
          Title: `Invoice ${invoice.id}`,
          Author: company.name,
          Subject: `Invoice for ${customer.name}`,
          CreationDate: invoice.createdAt.toDate(),
        },
      });

      // Collect PDF data
      const chunks: Buffer[] = [];
      doc.on('data', (chunk) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      // Generate PDF content
      generateHeader(doc, company, invoice);
      generateCustomerInfo(doc, customer);
      generateInvoiceDetails(doc, invoice);
      generateLineItems(doc, invoice);
      generateTotals(doc, invoice);
      generateFooter(doc, company);

      // Finalize PDF
      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Generate header with company logo and invoice title
 */
function generateHeader(doc: PDFKit.PDFDocument, company: CompanyData, invoice: InvoiceData) {
  doc
    .fontSize(20)
    .font('Helvetica-Bold')
    .text(company.name, 50, 50, { align: 'left' });

  // Company address
  if (company.address || company.city) {
    doc
      .fontSize(10)
      .font('Helvetica')
      .text(
        [
          company.address,
          company.city && company.state && company.zipCode
            ? `${company.city}, ${company.state} ${company.zipCode}`
            : null,
          company.phone ? `Phone: ${company.phone}` : null,
          company.email ? `Email: ${company.email}` : null,
        ]
          .filter(Boolean)
          .join('\n'),
        50,
        75,
        { align: 'left' }
      );
  }

  // Invoice title (right-aligned)
  doc
    .fontSize(20)
    .font('Helvetica-Bold')
    .text('INVOICE', 350, 50, { align: 'right' });

  // Invoice number and date
  const createdDate = invoice.createdAt.toDate();
  const dueDate = invoice.dueDate.toDate();

  doc
    .fontSize(10)
    .font('Helvetica')
    .text(`Invoice #: ${(invoice.id || 'DRAFT').slice(-8).toUpperCase()}`, 350, 75, { align: 'right' })
    .text(`Date: ${formatDate(createdDate)}`, 350, 90, { align: 'right' })
    .text(`Due Date: ${formatDate(dueDate)}`, 350, 105, { align: 'right' });

  // Horizontal line
  doc
    .strokeColor('#cccccc')
    .lineWidth(1)
    .moveTo(50, 150)
    .lineTo(550, 150)
    .stroke();
}

/**
 * Generate customer billing information
 */
function generateCustomerInfo(doc: PDFKit.PDFDocument, customer: CustomerData) {
  doc
    .fontSize(12)
    .font('Helvetica-Bold')
    .text('Bill To:', 50, 170);

  doc
    .fontSize(10)
    .font('Helvetica')
    .text(customer.name, 50, 190)
    .text(
      [
        customer.address,
        customer.city && customer.state && customer.zipCode
          ? `${customer.city}, ${customer.state} ${customer.zipCode}`
          : null,
        customer.email ? `Email: ${customer.email}` : null,
        customer.phone ? `Phone: ${customer.phone}` : null,
      ]
        .filter(Boolean)
        .join('\n'),
      50,
      205
    );
}

/**
 * Generate invoice details (status, notes)
 */
function generateInvoiceDetails(doc: PDFKit.PDFDocument, invoice: InvoiceData) {
  const yPosition = 170;

  doc
    .fontSize(12)
    .font('Helvetica-Bold')
    .text('Invoice Details:', 350, yPosition, { align: 'right' });

  doc
    .fontSize(10)
    .font('Helvetica')
    .text(`Status: ${invoice.status.toUpperCase()}`, 350, yPosition + 20, { align: 'right' });

  if (invoice.notes) {
    doc
      .fontSize(9)
      .font('Helvetica-Oblique')
      .text(`Note: ${invoice.notes}`, 50, 270, { width: 500, align: 'left' });
  }
}

/**
 * Generate line items table
 */
function generateLineItems(doc: PDFKit.PDFDocument, invoice: InvoiceData) {
  const tableTop = 320;
  const descriptionX = 50;
  const quantityX = 320;
  const unitPriceX = 390;
  const amountX = 480;

  // Table header
  doc
    .fontSize(10)
    .font('Helvetica-Bold')
    .text('Description', descriptionX, tableTop)
    .text('Quantity', quantityX, tableTop)
    .text('Unit Price', unitPriceX, tableTop)
    .text('Amount', amountX, tableTop);

  // Header underline
  doc
    .strokeColor('#cccccc')
    .lineWidth(1)
    .moveTo(50, tableTop + 15)
    .lineTo(550, tableTop + 15)
    .stroke();

  // Line items
  let yPosition = tableTop + 25;

  doc.fontSize(9).font('Helvetica');

  for (const item of invoice.items) {
    const lineAmount = item.quantity * item.unitPrice;

    // Check if we need a new page
    if (yPosition > 700) {
      doc.addPage();
      yPosition = 50;
    }

    // Description (wrap if too long)
    doc.text(item.description, descriptionX, yPosition, { width: 260, align: 'left' });

    // Quantity
    doc.text(item.quantity.toFixed(2), quantityX, yPosition, { width: 60, align: 'right' });

    // Unit price
    doc.text(`$${item.unitPrice.toFixed(2)}`, unitPriceX, yPosition, { width: 80, align: 'right' });

    // Amount
    doc.text(`$${lineAmount.toFixed(2)}`, amountX, yPosition, { width: 70, align: 'right' });

    yPosition += 20;
  }

  // Bottom line
  doc
    .strokeColor('#cccccc')
    .lineWidth(1)
    .moveTo(50, yPosition + 5)
    .lineTo(550, yPosition + 5)
    .stroke();

  return yPosition + 20;
}

/**
 * Generate totals section (subtotal, tax, total)
 */
function generateTotals(doc: PDFKit.PDFDocument, invoice: InvoiceData) {
  const yPosition = 530;
  const labelX = 390;
  const valueX = 480;

  // Subtotal
  const subtotal = invoice.items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);

  doc
    .fontSize(10)
    .font('Helvetica')
    .text('Subtotal:', labelX, yPosition, { align: 'right' })
    .text(`$${subtotal.toFixed(2)}`, valueX, yPosition, { width: 70, align: 'right' });

  // Tax (if applicable)
  let taxAmount = 0;
  let currentY = yPosition + 20;

  if (invoice.taxRate && invoice.taxRate > 0) {
    taxAmount = subtotal * invoice.taxRate;
    doc
      .text(`Tax (${(invoice.taxRate * 100).toFixed(1)}%):`, labelX, currentY, { align: 'right' })
      .text(`$${taxAmount.toFixed(2)}`, valueX, currentY, { width: 70, align: 'right' });
    currentY += 20;
  }

  // Total
  const total = subtotal + taxAmount;

  doc
    .fontSize(12)
    .font('Helvetica-Bold')
    .text('Total:', labelX, currentY, { align: 'right' })
    .text(`$${total.toFixed(2)}`, valueX, currentY, { width: 70, align: 'right' });

  // Currency
  doc
    .fontSize(8)
    .font('Helvetica')
    .text(`(${invoice.currency})`, valueX, currentY + 15, { width: 70, align: 'right' });
}

/**
 * Generate footer with payment instructions
 */
function generateFooter(doc: PDFKit.PDFDocument, company: CompanyData) {
  const footerTop = 680;

  // Payment instructions
  doc
    .fontSize(10)
    .font('Helvetica-Bold')
    .text('Payment Instructions:', 50, footerTop);

  doc
    .fontSize(9)
    .font('Helvetica')
    .text(
      'Please make payment by the due date shown above.\n' +
        'For questions regarding this invoice, please contact us at:',
      50,
      footerTop + 15
    );

  if (company.email || company.phone) {
    doc.text(
      [company.email ? `Email: ${company.email}` : null, company.phone ? `Phone: ${company.phone}` : null]
        .filter(Boolean)
        .join(' | '),
      50,
      footerTop + 45
    );
  }

  // Footer line
  doc
    .strokeColor('#cccccc')
    .lineWidth(1)
    .moveTo(50, 750)
    .lineTo(550, 750)
    .stroke();

  // Thank you message
  doc
    .fontSize(8)
    .font('Helvetica-Oblique')
    .text(`Thank you for your business!`, 50, 760, { align: 'center', width: 500 });
}

/**
 * Format date as MM/DD/YYYY
 */
function formatDate(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const year = date.getFullYear();
  return `${month}/${day}/${year}`;
}

/**
 * Generate PDF filename for storage
 *
 * @param invoiceId - Invoice ID
 * @param companyId - Company ID
 * @returns Filename in format: invoices/{companyId}/{invoiceId}.pdf
 */
export function getInvoicePDFPath(invoiceId: string, companyId: string): string {
  return `invoices/${companyId}/${invoiceId}.pdf`;
}
