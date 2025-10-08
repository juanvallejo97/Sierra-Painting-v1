import PDFDocument from "pdfkit";
export async function createPdfService(estimate) {
    return new Promise((resolve, reject) => {
        const doc = new PDFDocument();
        const buffers = [];
        doc.on("data", buffers.push.bind(buffers));
        doc.on("end", () => {
            const pdfBuffer = Buffer.concat(buffers);
            resolve(pdfBuffer);
        });
        doc.on("error", reject);
        // Header
        doc.fontSize(20).text("Sierra Painting", { align: "center" });
        doc.fontSize(16).text("Estimate", { align: "center" });
        doc.moveDown();
        // Items
        doc.fontSize(12).text("Items:", { underline: true });
        doc.moveDown(0.5);
        let subtotal = 0;
        estimate.items.forEach((item) => {
            const total = item.qty * item.unitPrice; // Changed from quantity to qty
            subtotal += total;
            doc.fontSize(10)
                .text(`${item.description} - Qty: ${item.qty} x $${item.unitPrice} = $${total.toFixed(2)}`);
        });
        doc.moveDown();
        // Tax and discount
        const taxAmount = subtotal * estimate.taxRate;
        const afterDiscount = subtotal - estimate.discount;
        const grandTotal = afterDiscount + taxAmount;
        doc.text(`Subtotal: $${subtotal.toFixed(2)}`);
        if (estimate.discount > 0) {
            doc.text(`Discount: -$${estimate.discount.toFixed(2)}`);
        }
        if (estimate.taxRate > 0) {
            doc.text(`Tax (${(estimate.taxRate * 100).toFixed(1)}%): $${taxAmount.toFixed(2)}`);
        }
        doc.moveDown();
        // Total
        doc.fontSize(14)
            .text(`Total: $${grandTotal.toFixed(2)}`, { align: "right" });
        doc.end();
    });
}
