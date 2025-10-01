import PDFDocument from "pdfkit";
import {Estimate} from "../schemas";

export async function createPdfService(estimate: Estimate): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument();
    const buffers: Buffer[] = [];

    doc.on("data", buffers.push.bind(buffers));
    doc.on("end", () => {
      const pdfBuffer = Buffer.concat(buffers);
      resolve(pdfBuffer);
    });
    doc.on("error", reject);

    // Header
    doc.fontSize(20).text("Sierra Painting", {align: "center"});
    doc.fontSize(16).text("Estimate", {align: "center"});
    doc.moveDown();

    // Items
    doc.fontSize(12).text("Items:", {underline: true});
    doc.moveDown(0.5);

    let subtotal = 0;
    estimate.items.forEach((item) => {
      const total = item.quantity * item.unitPrice;
      subtotal += total;
      doc.fontSize(10)
        .text(
          `${item.description} - Qty: ${item.quantity} x $${item.unitPrice} = $${total.toFixed(2)}`
        );
    });

    doc.moveDown();

    // Labor
    const laborTotal = estimate.laborHours * estimate.laborRate;
    doc.text(
      `Labor: ${estimate.laborHours} hours x $${estimate.laborRate}/hr = $${laborTotal.toFixed(2)}`
    );

    doc.moveDown();

    // Total
    const grandTotal = subtotal + laborTotal;
    doc.fontSize(14)
      .text(`Total: $${grandTotal.toFixed(2)}`, {align: "right"});

    // Notes
    if (estimate.notes) {
      doc.moveDown();
      doc.fontSize(10).text("Notes:", {underline: true});
      doc.text(estimate.notes);
    }

    doc.end();
  });
}
