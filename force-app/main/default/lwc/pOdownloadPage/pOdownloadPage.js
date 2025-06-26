import { LightningElement, wire, api } from 'lwc';
import getPurchaseOrderDetails from '@salesforce/apex/PurchaseOrderController.getPurchaseOrderDetails';
import unitTaxablePrice from '@salesforce/apex/PurchaseOrderController.unitTaxablePrice';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jsPDFResource from '@salesforce/resourceUrl/jspdf';

export default class POdownloadPage extends LightningElement {
    @api recordId;

    purchaseOrder;
    error;
    jsPDFLoaded = false;

    // Consignor Details - Supplier Distributor
    consignorName;
    consignorAddress;
    consignorCity;
    consignorState;
    consignorPinCode;
    consignorPanNumber;
    consignorGstNumber;
    consignorDLNumber;

    // Consignee Details - Account
    consigneeName;
    consigneeAddress;
    consigneeCity;
    consigneeState;
    consigneePinCode;
    consigneePanNumber;
    consigneeGstNumber;
    consigneeDLNumber;

    purchaseOrderProducts = [];

    totalTaxableValue = 0;
    totalCGSTAmount = 0;
    totalSGSTAmount = 0;
    totalIGSTAmount = 0;
    totalFinalValue = 0;

    amountInWords = '';
    comment;
    unitTaxablePrice;

    connectedCallback() {
        this.loadjsPDF();
    }

    loadjsPDF() {
        loadScript(this, jsPDFResource)
            .then(() => {
                this.jsPDFLoaded = true;
                console.log('jsPDF loaded successfully');
            })
            .catch(error => {
                console.error('Error loading jsPDF:', error);
                this.showToast('Error', 'Failed to load PDF library', 'error');
            });
    }

    @wire(unitTaxablePrice, { recordId: '$recordId' })
    wiredUnitTaxablePrice({ error, data }) {
        if (data) {
            this.unitTaxablePrice = data;
            this.error = undefined;
            console.log('Unit Taxable Price:', JSON.stringify(this.unitTaxablePrice));
        } else if (error) {
            this.error = error;
            this.unitTaxablePrice = undefined;
            console.error('Error fetching Unit Taxable Price:', JSON.stringify(this.error));
        }
    }

    @wire(getPurchaseOrderDetails, { recordId: '$recordId' })
    wiredPurchaseOrder({ error, data }) {
        if (data) {
            this.purchaseOrder = data.purchaseOrder;
            this.error = undefined;
            console.log('Purchase Order Data:', JSON.stringify(this.purchaseOrder));

            this.comment = this.purchaseOrder.Comment__c || '';

            // Consignor Details
            const consignor = this.purchaseOrder.Supplier_Distributor__r || {};
            this.consignorName = consignor.Name || '';
            this.consignorAddress = consignor.Address__c || '';
            this.consignorCity = consignor.City__c || '';
            this.consignorState = consignor.State__c || '';
            this.consignorPinCode = consignor.Account_Pin_Code__c || '';
            this.consignorPanNumber = consignor.PAN_Number__c || '';
            this.consignorGstNumber = consignor.GST_Number__c || '';
            this.consignorDLNumber = consignor.Drug_Licence_Number__c || '';
            console.log('Consignor Details:', JSON.stringify({ consignor }));

            // Consignee Details
            const consignee = this.purchaseOrder.Account__r || {};
            this.consigneeName = consignee.Name || '';
            this.consigneeAddress = consignee.Address__c || '';
            this.consigneeCity = consignee.City__c || '';
            this.consigneeState = consignee.State__c || '';
            this.consigneePinCode = consignee.Account_Pin_Code__c || '';
            this.consigneePanNumber = consignee.PAN_Number__c || '';
            this.consigneeGstNumber = consignee.GST_Number__c || '';
            this.consigneeDLNumber = consignee.Drug_Licence_Number__c || '';
            console.log('Consignee Details:', JSON.stringify({ consignee }));

            this.totalCGSTAmount = 0;
            this.totalSGSTAmount = 0;
            this.totalIGSTAmount = 0;
            this.totalCGSTRate = 0;
            this.totalSGSTRate = 0;
            this.totalIGSTRate = 0;
            this.totalTaxableValue = 0;
            this.totalFinalValue = 0;

            this.purchaseOrderProducts = [];
            let counter = 1;

            (this.purchaseOrder.Purchase_Order_Products__r || []).forEach(product => {
                // const unitPrice = product.UnitPrice__c || 0;
                // const quantity = product.Quantity__c || 0;

                // // Tax rates from Tax_Master__r
                // const cgstRate = product.Zydus_Product__r?.Tax_Master__r?.CGST_Percentage__c || 0;
                // const sgstRate = product.Zydus_Product__r?.Tax_Master__r?.SGST_Percentage__c || 0;
                // const igstRate = product.Zydus_Product__r?.Tax_Master__r?.IGST_Percentage__c || 0;

                // // Tax amounts
                // const cgstAmount = (unitPrice * cgstRate) / 100;
                // const sgstAmount = (unitPrice * sgstRate) / 100;
                // const igstAmount = (unitPrice * igstRate) / 100;

                // // Total value including tax
                // const totalValue = unitPrice + cgstAmount + sgstAmount + igstAmount;

                // this.totalCGSTAmount += cgstAmount;
                // this.totalSGSTAmount += sgstAmount;
                // this.totalIGSTAmount += igstAmount;
                // this.totalTaxableValue += unitPrice;
                // this.totalFinalValue += totalValue;

                //const hsn = product.Zydus_Product__r.Tax_Master__r.HSN_Code__c || '';

                const unitPrice = product.UnitPrice__c || 0;
                const quantity = product.Quantity__c || 0;
                const grossAmount = product.Purchase_Order_Amount__c || 0;
                const igst = product.IGST__c || 0;
                const cgst = product.CGST__c || 0;
                const sgst = product.SGST__c || 0;

                const cgstRate = (cgst * 100) / unitPrice;
                const sgstRate = (sgst * 100) / unitPrice;
                const igstRate = (igst * 100) / unitPrice;

                const totalValue = grossAmount + cgst + sgst + igst;
                this.totalCGSTAmount += cgst;
                this.totalSGSTAmount += sgst;
                this.totalIGSTAmount += igst;
                this.totalTaxableValue += unitPrice;
                this.totalFinalValue += totalValue;

                this.purchaseOrderProducts.push({
                    id: counter++,
                    productName: product.Zydus_Product__r.Name,
                    length: product.Zydus_Product__r.Length__c,
                    diameter: product.Zydus_Product__r.Diameter__c,
                    hsn: '',
                    CGSTRate: cgstRate,
                    SGSTRate: sgstRate,
                    IGSTRate: igstRate,
                    quantity: quantity,
                    unitPrice: unitPrice.toFixed(2),
                    CGSTAmount: cgst.toFixed(2),
                    SGSTAmount: sgst.toFixed(2),
                    IGSTAmount: igst.toFixed(2),
                    totalAmount: totalValue.toFixed(2)
                });

                this.amountInWords = this.convertNumberToWords(this.totalFinalValue);
            });

        } else if (error) {
            this.error = error;
            this.purchaseOrder = undefined;
            console.error('Error fetching Purchase Order:', JSON.stringify(this.error));
        }
    }

    handleDownloadPDF() {
        if (!this.jsPDFLoaded) {
            this.showToast('Error', 'PDF library not loaded yet. Please try again.', 'error');
            return;
        }

        try {
            this.generatePDF();
        } catch (error) {
            console.error('Error generating PDF:', error);
            this.showToast('Error', 'Failed to generate PDF. Please try again.', 'error');
        }
    }

    generatePDF() {
        const jsPDF = window.jspdf?.jsPDF || window.jsPDF;
        if (!jsPDF) {
            throw new Error('jsPDF library not found');
        }

        const doc = new jsPDF('landscape', 'mm', 'a4');
        let yPosition = 15;
        const pageWidth = doc.internal.pageSize.getWidth();
        const pageHeight = doc.internal.pageSize.getHeight();
        const margin = 10;

        // Header Section - PURCHASE ORDER with border
        doc.setDrawColor(0, 0, 0);
        doc.setLineWidth(0.8);
        doc.rect(margin, yPosition, pageWidth - margin * 2, 15);

        doc.setFillColor(245, 245, 245);
        doc.rect(margin, yPosition, pageWidth - margin * 2, 15, 'F');

        doc.setFont('helvetica', 'bold');
        doc.setFontSize(16);
        doc.setTextColor(0, 0, 0);
        doc.text('PURCHASE ORDER', pageWidth / 2, yPosition + 10, { align: 'center' });
        yPosition += 20;

        // Bill From/To Section
        const sectionHeight = 65;
        const sectionWidth = (pageWidth - margin * 2) / 2 - 5;

        doc.setFillColor(255, 255, 255);
        doc.rect(margin, yPosition, pageWidth - margin * 2, sectionHeight, 'F');

        const dividerX = margin + sectionWidth + 5;
        doc.setDrawColor(220, 230, 240);
        doc.setLineWidth(0.3);
        doc.line(dividerX, yPosition + 5, dividerX, yPosition + sectionHeight - 5);

        // Left Section - Consignee Bill From
        doc.setFillColor(245, 245, 245);
        doc.roundedRect(margin + 3, yPosition + 3, sectionWidth - 1, sectionHeight - 6, 3, 3, 'F');

        let leftY = yPosition + 12;
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.setTextColor(60, 80, 100);
        doc.text('Consignee Bill From :-', margin + 8, leftY);

        leftY += 8;
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(9);
        doc.setTextColor(80, 100, 120);

        const leftDetails = [
            this.consigneeName || 'Sub Distributor 10.06',
            this.consigneeAddress || 'Ahmedabad',
            `${this.consigneeCity || 'Ahmedabad'}, ${this.consigneeState || 'Gujarat'} - ${this.consigneePinCode || '445896'}`,
            `GSTIN No. :${this.consigneeGstNumber || '-44563322895554125'}`,
            `PAN :${this.consigneePanNumber || '-7784445214'}`,
            `DL No. :${this.consigneeDLNumber || '-87854542121215214584'}`
        ];

        leftDetails.forEach(detail => {
            if (detail) {
                doc.text(detail, margin + 8, leftY);
            }
            leftY += 5;
        });

        // Right Section - Consignor Bill To
        const rightSectionX = dividerX + 5;
        doc.setFillColor(245, 245, 245);
        doc.roundedRect(rightSectionX, yPosition + 3, sectionWidth - 1, sectionHeight - 6, 3, 3, 'F');

        let rightY = yPosition + 12;
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.setTextColor(60, 80, 100);
        doc.text('Consignor Bill To:-', rightSectionX + 5, rightY);

        rightY += 8;
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(9);
        doc.setTextColor(80, 100, 120);

        const rightDetails = [
            this.consignorName || 'Super Distributor 10.06',
            this.consignorAddress || 'Ahmedabad',
            `${this.consignorCity || 'Ahmedabad'}, ${this.consignorState || 'Gujarat'} - ${this.consignorPinCode || '445512'}`,
            `${this.consignorState || 'Gujarat'}, INDIA`,
            `GSTIN No. :${this.consignorGstNumber || '-778544411125458'}`,
            `PAN :${this.consignorPanNumber || '-7784445211'}`,
            `DL No. :${this.consignorDLNumber || '-788787878787455544415'}`
        ];

        rightDetails.forEach(detail => {
            if (detail) {
                doc.text(detail, rightSectionX + 5, rightY);
            }
            rightY += 5;
        });

        doc.setTextColor(0, 0, 0);
        yPosition += sectionHeight + 10;

        // Product Table
        if (this.purchaseOrderProducts && this.purchaseOrderProducts.length > 0) {
            yPosition = this.drawOptimizedProductTable(doc, yPosition, margin, pageWidth, pageHeight);
        }

        // Check if we need new page for footer content (Amount in words + footer)
        const remainingSpace = pageHeight - yPosition;
        const footerContentHeight = 80; // Estimated height needed for footer content

        if (remainingSpace < footerContentHeight) {
            doc.addPage();
            yPosition = 20;
        }

        yPosition += 10;

        // Amount in Words - Keep on same page
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.text(`Amount (In Words): ${this.amountInWords || 'RUPEES SEVEN LAKH FORTY FOUR THOUSAND TWO HUNDRED AND TWENTY ONLY'}`, margin, yPosition);
        yPosition += 10;

        doc.setFont('helvetica', 'normal');
        doc.setFontSize(9);
        doc.text('All the products shipped are STERILE', margin, yPosition);
        yPosition += 5;
        doc.text('Goods once sold are not returnable.', margin, yPosition);
        yPosition += 5;
        doc.text(`Comments & Remarks: ${this.comment || 'Need to see this comment on PO'}`, margin, yPosition);
        yPosition += 15;

        // Payment Terms and Signature Section
        this.drawOptimizedFooterSection(doc, yPosition, margin, pageWidth, pageHeight);

        // Save PDF
        const fileName = `Purchase_Order_${this.recordId || 'Document'}.pdf`;
        doc.save(fileName);

        this.showToast('Success', 'PDF downloaded successfully!', 'success');
    }

    drawOptimizedProductTable(doc, startY, margin, pageWidth, pageHeight) {
        let yPosition = startY;
        const tableWidth = pageWidth - margin * 2;

        const headers = [
            'SR.NO.', 'PRODUCT NAME', 'DIAMETER', 'LENGTH', 'HSN', 'QUANTITY',
            'TAXABLE VALUE', 'CGST\nRATE', 'CGST\nAMT', 'SGST\nRATE', 'SGST\nAMT',
            'IGST\nRATE', 'IGST\nAMT', 'TOTAL\nVALUE'
        ];

        const colWidths = [15, 45, 20, 18, 15, 20, 25, 18, 18, 18, 18, 18, 18, 25];
        const totalWidth = colWidths.reduce((sum, width) => sum + width, 0);

        if (totalWidth > tableWidth) {
            const scale = tableWidth / totalWidth;
            for (let i = 0; i < colWidths.length; i++) {
                colWidths[i] = colWidths[i] * scale;
            }
        }

        const rowHeight = 12;
        const headerHeight = 16;

        // Draw table header
        this.drawTableHeader(doc, yPosition, margin, headers, colWidths, headerHeight);
        yPosition += headerHeight;

        // Draw table rows
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8);
        doc.setTextColor(0, 0, 0);
        doc.setDrawColor(180, 180, 180);

        this.purchaseOrderProducts.forEach((product, rowIndex) => {
            // More generous page break check - leave more space for totals row
            if (yPosition > pageHeight - 80) { // Increased from 80 to 100
                doc.addPage();
                yPosition = 20;

                // Redraw headers on new page
                this.drawTableHeader(doc, yPosition, margin, headers, colWidths, headerHeight);
                yPosition += headerHeight;

                // Reset styles after page break
                doc.setFont('helvetica', 'normal');
                doc.setFontSize(8);
                doc.setTextColor(0, 0, 0);
                doc.setDrawColor(180, 180, 180);
            }

            // Draw row
            doc.setFillColor(255, 255, 255);
            doc.rect(margin, yPosition, tableWidth, rowHeight, 'F');

            doc.setDrawColor(180, 180, 180);
            doc.setLineWidth(0.3);
            doc.rect(margin, yPosition, tableWidth, rowHeight);

            const rowData = [
                (rowIndex + 1).toString(),
                product.productName || '',
                product.diameter || 'N/A',
                product.length || '',
                product.hsn || '',
                product.quantity?.toString() || '',
                product.unitPrice?.toString() || '',
                (product.CGSTRate || 0) + '%',
                product.CGSTAmount?.toString() || '0.00',
                (product.SGSTRate || 0) + '%',
                product.SGSTAmount?.toString() || '0.00',
                (product.IGSTRate || 0) + '%',
                product.IGSTAmount?.toString() || '0.00',
                product.totalAmount?.toString() || '0.00'
            ];

            let xPosition = margin;
            rowData.forEach((data, colIndex) => {
                const cellData = data.toString();

                if (colIndex === 1) { // Product name column
                    this.drawWrappedText(doc, cellData, xPosition + 2, yPosition + 3, colWidths[colIndex] - 4, rowHeight - 2, 'left');
                } else {
                    const maxWidth = colWidths[colIndex] - 4;
                    doc.text(cellData, xPosition + colWidths[colIndex] / 2, yPosition + rowHeight / 2 + 1, {
                        align: 'center',
                        maxWidth: maxWidth
                    });
                }

                if (colIndex < rowData.length - 1) {
                    doc.setDrawColor(180, 180, 180);
                    doc.line(xPosition + colWidths[colIndex], yPosition, xPosition + colWidths[colIndex], yPosition + rowHeight);
                }
                xPosition += colWidths[colIndex];
            });

            yPosition += rowHeight;
        });

        // Draw totals row
        doc.setFillColor(240, 240, 240);
        doc.rect(margin, yPosition, tableWidth, rowHeight, 'F');

        doc.setDrawColor(180, 180, 180);
        doc.setLineWidth(0.5);
        doc.rect(margin, yPosition, tableWidth, rowHeight);

        doc.setFont('helvetica', 'bold');
        doc.setFontSize(9);
        doc.setTextColor(0, 0, 0);

        // Draw totals with proper spacing
        const totalLabelWidth = colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4];
        const totalValueWidth = colWidths[5];
        const taxableValueWidth = colWidths[6];
        const cgstAmtWidth = colWidths[7] + colWidths[8];
        const sgstAmtWidth = colWidths[9] + colWidths[10];
        const igstAmtWidth = colWidths[11] + colWidths[12];
        const finalTotalWidth = colWidths[13];

        let totalXPos = margin;

        doc.text('Total', totalXPos + totalLabelWidth + totalValueWidth / 2, yPosition + rowHeight / 2 + 1, { align: 'center' });
        totalXPos += totalLabelWidth + totalValueWidth;

        doc.setDrawColor(180, 180, 180);
        doc.line(totalXPos, yPosition, totalXPos, yPosition + rowHeight);

        doc.text((this.totalTaxableValue?.toFixed(2) || '619000.00'), totalXPos + taxableValueWidth / 2, yPosition + rowHeight / 2 + 1, { align: 'center' });
        totalXPos += taxableValueWidth;
        doc.line(totalXPos, yPosition, totalXPos, yPosition + rowHeight);

        doc.text((this.totalCGSTAmount?.toFixed(2) || '62610.00'), totalXPos + cgstAmtWidth / 2, yPosition + rowHeight / 2 + 1, { align: 'center' });
        totalXPos += cgstAmtWidth;
        doc.line(totalXPos, yPosition, totalXPos, yPosition + rowHeight);

        doc.text((this.totalSGSTAmount?.toFixed(2) || '62610.00'), totalXPos + sgstAmtWidth / 2, yPosition + rowHeight / 2 + 1, { align: 'center' });
        totalXPos += sgstAmtWidth;
        doc.line(totalXPos, yPosition, totalXPos, yPosition + rowHeight);

        doc.text('0.00', totalXPos + igstAmtWidth / 2, yPosition + rowHeight / 2 + 1, { align: 'center' });
        totalXPos += igstAmtWidth;
        doc.line(totalXPos, yPosition, totalXPos, yPosition + rowHeight);

        doc.text((this.totalFinalValue?.toFixed(2) || '744220.00'), totalXPos + finalTotalWidth / 2, yPosition + rowHeight / 2 + 1, { align: 'center' });

        yPosition += rowHeight;
        return yPosition;
    }

    // New helper method to draw table headers
    drawTableHeader(doc, yPosition, margin, headers, colWidths, headerHeight) {
        const tableWidth = colWidths.reduce((sum, width) => sum + width, 0);

        doc.setFillColor(240, 240, 240);
        doc.rect(margin, yPosition, tableWidth, headerHeight, 'F');

        doc.setDrawColor(180, 180, 180);
        doc.setLineWidth(0.5);
        doc.rect(margin, yPosition, tableWidth, headerHeight);

        doc.setTextColor(0, 0, 0);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(7);

        let xPosition = margin;
        headers.forEach((header, index) => {
            const lines = header.split('\n');
            if (lines.length > 1) {
                lines.forEach((line, lineIndex) => {
                    doc.text(line, xPosition + colWidths[index] / 2, yPosition + 5 + (lineIndex * 4), {
                        align: 'center',
                        maxWidth: colWidths[index] - 2
                    });
                });
            } else {
                doc.text(header, xPosition + colWidths[index] / 2, yPosition + headerHeight / 2 + 1, {
                    align: 'center',
                    maxWidth: colWidths[index] - 2
                });
            }

            if (index < headers.length - 1) {
                doc.setDrawColor(180, 180, 180);
                doc.line(xPosition + colWidths[index], yPosition, xPosition + colWidths[index], yPosition + headerHeight);
            }
            xPosition += colWidths[index];
        });
    }

    drawWrappedText(doc, text, x, y, maxWidth, maxHeight, align = 'left') {
        const words = text.split(' ');
        let lines = [];
        let currentLine = '';

        words.forEach(word => {
            const testLine = currentLine + (currentLine ? ' ' : '') + word;
            const textWidth = doc.getTextWidth(testLine);

            if (textWidth > maxWidth && currentLine) {
                lines.push(currentLine);
                currentLine = word;
            } else {
                currentLine = testLine;
            }
        });

        if (currentLine) {
            lines.push(currentLine);
        }

        const lineHeight = 3;
        const startY = y + lineHeight;

        lines.forEach((line, index) => {
            if ((index + 1) * lineHeight <= maxHeight) {
                doc.text(line, align === 'center' ? x + maxWidth / 2 : x, startY + (index * lineHeight), { align: align });
            }
        });
    }

    drawOptimizedFooterSection(doc, startY, margin, pageWidth, pageHeight) {
        let yPosition = startY;

        // Check if footer will fit on current page
        const estimatedFooterHeight = 120; // Estimated height for all footer content
        if (yPosition + estimatedFooterHeight > pageHeight - 20) {
            doc.addPage();
            yPosition = 20;
        }

        const leftColumnWidth = pageWidth * 0.65;
        const rightColumnStart = leftColumnWidth + 10;
        const rightColumnWidth = pageWidth - rightColumnStart - margin;

        // Payment Terms - Left Column
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.text('Payment Terms :-', margin, yPosition);
        yPosition += 8;

        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8);

        const terms = [
            'Interest will be recovered @2% p.a. on overdue unpaid bills.',
            'Shipping Instructions:',
            '• Avoid exposure to direct sunlight or heaters & Keep the products in a clean, organized cold and dry place',
            '• For Reference No please refer Product Catalogue',
            '• It will be sole responsibility of the Consignee to monitor non use of expired product.',
            '• Subject to Ahmedabad Jurisdiction.',
            '• Goods once sold are not returnable.',
            '• Our risk and responsibility cease once the goods leave our premises.',
            '• Claim for any loss in the consignment should be settled by the buyer directly with the carrier.',
            'Declaration:',
            '• We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct',
            '• E&OE'
        ];

        let leftColumnY = yPosition;
        terms.forEach(term => {
            if (term === 'Shipping Instructions:' || term === 'Declaration:') {
                doc.setFont('helvetica', 'bold');
            } else {
                doc.setFont('helvetica', 'normal');
            }

            if (term.startsWith('•')) {
                doc.text(term, margin + 5, leftColumnY);
            } else {
                doc.text(term, margin, leftColumnY);
            }
            leftColumnY += 4;
        });

        // Signature Section - Right Column
        const signatureStartY = yPosition;
        const signatureBoxHeight = 60;
        const signatureBoxWidth = rightColumnWidth;

        doc.setFillColor(245, 245, 245);
        doc.rect(rightColumnStart, signatureStartY - 5, signatureBoxWidth, signatureBoxHeight, 'F');

        doc.setDrawColor(200, 200, 200);
        doc.setLineWidth(0.5);
        doc.rect(rightColumnStart, signatureStartY - 5, signatureBoxWidth, signatureBoxHeight);

        doc.setDrawColor(0, 0, 0);
        doc.setTextColor(0, 0, 0);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(9);

        const signatureBoxCenter = rightColumnStart + (signatureBoxWidth / 2);

        // Receiver Signature
        const receiverY = signatureStartY + 15;
        const receiverText = 'Receiver Signature';
        const receiverTextWidth = doc.getTextWidth(receiverText);
        doc.text(receiverText, signatureBoxCenter - (receiverTextWidth / 2), receiverY);

        const lineWidth = 80;
        doc.setLineWidth(0.2);
        doc.line(signatureBoxCenter - (lineWidth / 2), receiverY + 12, signatureBoxCenter + (lineWidth / 2), receiverY + 12);

        // Authorised Signatory
        const authorisedY = receiverY + 25;
        const authorisedText = 'Authorised Signatory';
        const authorisedTextWidth = doc.getTextWidth(authorisedText);
        doc.text(authorisedText, signatureBoxCenter - (authorisedTextWidth / 2), authorisedY);
    }


    convertNumberToWords(amount) {
        const ones = [
            "", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE",
            "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN",
            "SEVENTEEN", "EIGHTEEN", "NINETEEN"
        ];
        const tens = ["", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"];

        const getWords = (num) => {
            if (num === 0) return "";
            if (num < 20) return ones[num];
            return tens[Math.floor(num / 10)] + (num % 10 ? " " + ones[num % 10] : "");
        };

        const getSegment = (num, label) => {
            if (num === 0) return "";
            return `${convertToWords(num)} ${label} `;
        };

        const convertToWords = (num) => {
            let result = "";

            const crore = Math.floor(num / 10000000);
            const lakh = Math.floor((num % 10000000) / 100000);
            const thousand = Math.floor((num % 100000) / 1000);
            const hundred = Math.floor((num % 1000) / 100);
            const rest = num % 100;

            if (crore) result += getSegment(crore, "CRORE");
            if (lakh) result += getSegment(lakh, "LAKH");
            if (thousand) result += getSegment(thousand, "THOUSAND");
            if (hundred) result += `${ones[hundred]} HUNDRED `;

            if (rest && result !== "") result += "AND ";
            result += getWords(rest);

            return result.trim();
        };

        const rupees = Math.floor(amount);
        const paisa = Math.round((amount - rupees) * 100);

        const rupeesWords = convertToWords(rupees) || "ZERO";
        const paisaWords = paisa > 0 ? `${convertToWords(paisa)} PAISA` : "";

        return `RUPEES ${rupeesWords}${paisaWords ? ' AND ' + paisaWords : ''} ONLY`;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}