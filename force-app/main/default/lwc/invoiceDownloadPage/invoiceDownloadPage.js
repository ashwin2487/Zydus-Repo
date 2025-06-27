import { LightningElement, api, track, wire } from 'lwc';
import getInvoiceDetails from '@salesforce/apex/InvoiceController.getInvoiceDetails';
import recordType from '@salesforce/apex/InvoiceController.getRecordType';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jsPDFResource from '@salesforce/resourceUrl/jspdf';

export default class InvoiceDownloadPage extends LightningElement {
    @api recordId;

    invoiceDetails;
    consignorWarehouse;
    consigneeWarehouse;
    error;
    hospitalRecordType;

    jsPDFLoaded = false;

    async connectedCallback() {
        try {
            await loadScript(this, jsPDFResource);
            this.jsPDFLoaded = true;
            console.log('jsPDF loaded successfully');
        } catch (error) {
            console.error('Error loading jsPDF:', error);
            this.showToast('Error', 'Failed to load PDF library', 'error');
        }
    }

    // Consignor Details
    consignorName;
    consignorAddress;
    consignorCity;
    consignorState;
    consignorPinCode;
    consignorPanNumber;
    consignorGstNumber;
    consignorDLNumber;

    // Consignor Ship From
    consignorShipAddress;
    consignorShipCity;
    consignorShipState;
    consignorShipPinCode;

    // Consignee Details
    consigneeName;
    consigneeAddress;
    consigneeCity;
    consigneeState;
    consigneePinCode;
    consigneePanNumber;
    consigneeGstNumber;
    consigneeDLNumber;

    // Consignee Ship To
    consigneeShipAddress;
    consigneeShipCity;
    consigneeShipState;
    consigneeShipPinCode;

    // invoice details
    invoiceNumber;
    invoiceDate;
    invoiceDueDate;
    paymentTerm;
    patientName;
    patientAge;
    patientGender;
    doctorName;
    scheme;
    implantSerialNumber;
    implantBatchNumber;
    ipNumber;
    cathNumber;

    // total information
    totalAmount;
    totalCGSTAmount;
    totalSGSTAmount;
    totalIGSTAmount;
    totalCGSTRate;
    totalSGSTRate;
    totalIGSTRate;

    invoiceItems = [];

    amountInWords = '';

    netFinalAmount = 0;

    comments;

    @wire(recordType, { recordId: '$recordId' })
    wiredRecordType({ error, data }) {
        if (data) {
            this.hospitalRecordType = data;
            console.log('Hospital Record Type:', this.hospitalRecordType);
            console.log('Hospital Record Type (JSON):', JSON.stringify(this.hospitalRecordType));
        } else if (error) {
            this.error = error;
            console.error('Error fetching record type:', this.error);
        }
    }

    @wire(getInvoiceDetails, { recordId: '$recordId' })
    wiredInvoiceDetails({ error, data }) {
        if (data) {
            this.invoiceDetails = data.invoice;
            this.consignorWarehouse = data.consignorWarehouses;
            this.consigneeWarehouse = data.consigneeWarehouses;
            this.error = undefined;
            console.log('Invoice Details:', JSON.stringify(this.invoiceDetails));

            const consignor = this.invoiceDetails.Consignor_Dealer__r || {};
            this.consignorName = consignor.Name;
            this.consignorAddress = consignor.Address__c;
            this.consignorCity = consignor.City__c;
            this.consignorState = consignor.State__c;
            this.consignorPinCode = consignor.Pin_Code__c;
            this.consignorPanNumber = consignor.PAN_Number__c;
            this.consignorGstNumber = consignor.GST_Number__c;
            this.consignorDLNumber = consignor.DL_Number__c;
            console.log('Consignor details:', JSON.stringify(consignor));

            this.consignorShipAddress = this.consignorWarehouse.Address__c;
            this.consignorShipCity = this.consignorWarehouse.City__c;
            this.consignorShipState = this.consignorWarehouse.State__c;
            this.consignorShipPinCode = this.consignorWarehouse.Pin_Code__c;
            console.log('Consignor Ship From details:', JSON.stringify(this.consignorWarehouse));

            const consignee = this.invoiceDetails.Consignee_Dealer__r || {};
            this.consigneeName = consignee.Name;
            this.consigneeAddress = consignee.Address__c;
            this.consigneeCity = consignee.City__c;
            this.consigneeState = consignee.State__c;
            this.consigneePinCode = consignee.Pin_Code__c;
            this.consigneePanNumber = consignee.PAN_Number__c;
            this.consigneeGstNumber = consignee.GST_Number__c;
            this.consigneeDLNumber = consignee.DL_Number__c;
            console.log('Consignee details:', JSON.stringify(consignee));

            if (this.hospitalRecordType === 'Hospital') {
                this.consigneeShipAddress = consignee.Address__c;
                this.consigneeShipState = consignee.State__c;
                this.consigneeShipPinCode = consignee.Pin_Code__c;
                this.consigneeShipCity = consignee.City__c;
                console.log('Consignee Ship To details for Hospital:', JSON.stringify(consignee));
            }

            else {
                this.consigneeShipAddress = this.consigneeWarehouse.Address__c;
                this.consigneeShipCity = this.consigneeWarehouse.City__c;
                this.consigneeShipState = this.consigneeWarehouse.State__c;
                this.consigneeShipPinCode = this.consigneeWarehouse.Pin_Code__c;
                console.log('Consignee Ship To details:', JSON.stringify(this.consigneeWarehouse));
            }

            this.invoiceNumber = this.invoiceDetails.Name;
            this.invoiceDate = this.invoiceDetails.InvoiceDate__c;
            this.invoiceDueDate = this.invoiceDetails.Invoice_Due_Date__c;
            this.paymentTerm = consignee.Payment_Term__c;
            this.patientName = this.invoiceDetails.Patient_Name__c;
            this.patientAge = this.invoiceDetails.Patient_Age__c;
            this.patientGender = this.invoiceDetails.Patient_Gender__c;
            this.ipNumber = this.invoiceDetails.IP_Number__c;
            this.cathNumber = this.invoiceDetails.CATH_Number__c;
            this.comments = this.invoiceDetails.Comments__c;

            this.totalAmount = this.invoiceDetails.Total_Amount__c || 0;
            this.totalCGSTAmount = this.invoiceDetails.Total_CGST__c || 0;
            this.totalSGSTAmount = this.invoiceDetails.Total_SGST__c || 0;
            this.totalIGSTAmount = this.invoiceDetails.Total_IGST__c || 0;
            this.totalCGSTRate = (this.totalCGSTAmount * 100) / this.totalAmount;
            this.totalSGSTRate = (this.totalSGSTAmount * 100) / this.totalAmount;

            this.invoiceItems = [];
            let counter = 1;


            // Replace this section in your invoiceItems processing:
            (this.invoiceDetails.Invoice_Product_Line_Items__r || []).forEach(item => {
                const zydusProduct = item.Zydus_Product__r || {};
                const zydusProductName = zydusProduct.Name || '';
                const dia = zydusProduct.Diameter__c || '';
                const length = zydusProduct.Length__c || '';
                const description = zydusProduct.Material_Description__c || '';

                const cgst = item.CGST__c.toFixed(2) || 0;
                const sgst = item.SGST__c.toFixed(2) || 0;
                const igst = item.IGST__c.toFixed(2) || 0;
                const unitPrice = item.Unit_Price__c.toFixed(2) || 0;
                const netAmount = item.Net_Amount__c.toFixed(2) || 0;
                //const totalBeforeTax = (parseFloat(unitPrice) * parseFloat(item.Quantity__c || 1)).toFixed(2); // New field
                this.netFinalAmount = netAmount;
                this.scheme = item.Scheme__c || '';

                this.invoiceItems.push({
                    id: counter++,
                    productName: zydusProductName,
                    length: length,
                    diameter: dia,
                    description: description,
                    // quantity: item.Quantity__c, // REMOVED
                    batchNumber: item.Batch_Number__c,
                    serialNumber: item.Serial_Number__c,
                    unitPrice: unitPrice,
                    totalBeforeTax: 10, // NEW FIELD
                    hsn: item.HSN__c,
                    mfgDate: item.Manufacture_Date__c,
                    expiryDate: item.Expiry_Date__c,
                    cgst: cgst,
                    sgst: sgst,
                    igst: igst,
                    netAmount: netAmount,
                    cgstRate: ((cgst * 100) / netAmount).toFixed(2),
                    sgstRate: ((sgst * 100) / netAmount).toFixed(2),
                    igstRate: ((igst * 100) / netAmount).toFixed(2)
                });
            });

            this.amountInWords = this.convertNumberToWords(this.netFinalAmount);
        } else if (error) {
            this.error = error;
            this.invoiceDetails = undefined;
            console.error('Error fetching invoice details:', this.error);
        }
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

    async handleDownloadPDF() {
        if (!this.jsPDFLoaded) {
            this.showToast('Error', 'PDF library is not loaded', 'error');
            return;
        }
        try {
            this.generatePdf();
        }
        catch (error) {
            console.error('Error generating PDF:', error);
            console.error('Error details:', JSON.stringify(error));
            console.log('error message:', error.message);
            this.showToast('Error', 'Failed to generate PDF', 'error');
        }
    }


    generatePdf() {
        const jsPDF = window.jspdf?.jsPDF || window.jsPDF;
        if (!jsPDF) {
            throw new Error('jsPDF library not found');
        }
        const doc = new jsPDF('landscape', 'mm', 'a4');

        let yPosition = 10;
        const pageWidth = doc.internal.pageSize.getWidth();
        const pageHeight = doc.internal.pageSize.getHeight();
        const margin = 10;

        // Set lighter border style for all elements
        doc.setLineWidth(0.5);
        doc.setDrawColor(150, 150, 150);

        // const drawTableHeaders = (startY) => {
        //     // Updated headers without Unit Price
        //     const mainHeaders = [
        //         'Sr. No.', 'Product Name', 'Diameter', 'Length', 'Description', 'Batch No', 'Sr. No.',
        //         'Mfg. Date', 'Exp. Date', 'HSN', 'Total Before Tax', 'Taxable value', 'CGST', 'SGST', 'IGST', 'Total Value'
        //     ];

        //     // Updated widths without Unit Price column
        //     const mergedWidths = [
        //         12, 25, 12, 12, 30, 15, 15, 12, 12, 12, 18, 18, 22, 22, 22, 15
        //     ];

        //     const printableWidth = pageWidth - margin * 2;
        //     const headerHeight = 12;

        //     // Table headers - First row
        //     doc.setFillColor(240, 240, 240);
        //     doc.rect(margin, startY, printableWidth, headerHeight, 'F');
        //     doc.rect(margin, startY, printableWidth, headerHeight);
        //     let xPosition = margin;
        //     doc.setFont('helvetica', 'bold');
        //     doc.setFontSize(7);

        //     mainHeaders.forEach((header, index) => {
        //         doc.text(header, xPosition + mergedWidths[index] / 2, startY + headerHeight / 2, { align: 'center' });
        //         if (index > 0) {
        //             doc.line(xPosition, startY, xPosition, startY + headerHeight);
        //         }
        //         xPosition += mergedWidths[index];
        //     });

        //     let headerY = startY + headerHeight;

        //     // Table headers - Second row (Rate/Amt subheaders)
        //     doc.setFillColor(240, 240, 240);
        //     doc.rect(margin, headerY, printableWidth, headerHeight, 'F');
        //     doc.rect(margin, headerY, printableWidth, headerHeight);
        //     xPosition = margin;

        //     // Skip first 12 columns (reduced from 13)
        //     for (let i = 0; i < 12; i++) {
        //         if (i > 0) {
        //             doc.line(xPosition, headerY, xPosition, headerY + headerHeight);
        //         }
        //         xPosition += mergedWidths[i];
        //     }

        //     // Add Rate/Amt subheaders for CGST, SGST, IGST
        //     const taxColumns = ['CGST', 'SGST', 'IGST'];
        //     taxColumns.forEach((taxType, taxIndex) => {
        //         const taxWidth = mergedWidths[12 + taxIndex]; // Updated index
        //         const halfWidth = taxWidth / 2;

        //         // Rate column
        //         doc.text('Rate', xPosition + halfWidth / 2, headerY + headerHeight / 2, { align: 'center' });
        //         doc.line(xPosition, headerY, xPosition, headerY + headerHeight);
        //         xPosition += halfWidth;

        //         // Amt column  
        //         doc.text('Amt.', xPosition + halfWidth / 2, headerY + headerHeight / 2, { align: 'center' });
        //         doc.line(xPosition, headerY, xPosition, headerY + headerHeight);
        //         xPosition += halfWidth;
        //     });

        //     // Total Value column (no subheader)
        //     doc.line(xPosition, headerY, xPosition, headerY + headerHeight);

        //     return headerY + headerHeight;
        // };

        const drawTableHeaders = (startY) => {
            const mainHeaders = [
                'Sr. No.', 'Product Name', 'Diameter', 'Length', 'Description', 'Batch No', 'Sr. No.',
                'Mfg. Date', 'Exp. Date', 'HSN', 'Total Before Tax', 'Taxable value', 'CGST', 'SGST', 'IGST', 'Total Value'
            ];

            const mergedWidths = [
                12, 25, 12, 12, 30, 15, 15, 12, 12, 12, 18, 18, 22, 22, 22, 15
            ];

            const printableWidth = pageWidth - margin * 2;
            const headerHeight = 8; // Reduced height for more compact look

            // Single header row with subdivisions
            doc.setFillColor(240, 240, 240);
            doc.rect(margin, startY, printableWidth, headerHeight, 'F');
            doc.rect(margin, startY, printableWidth, headerHeight);
            let xPosition = margin;
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(7);

            // Draw main headers for first 12 columns
            for (let i = 0; i < 12; i++) {
                doc.text(mainHeaders[i], xPosition + mergedWidths[i] / 2, startY + headerHeight / 2, { align: 'center' });
                if (i > 0) {
                    doc.line(xPosition, startY, xPosition, startY + headerHeight);
                }
                xPosition += mergedWidths[i];
            }

            // Tax columns with Rate/Amt subdivisions in single row
            const taxColumns = ['CGST', 'SGST', 'IGST'];
            taxColumns.forEach((taxType, taxIndex) => {
                const taxWidth = mergedWidths[12 + taxIndex];
                const halfWidth = taxWidth / 2;

                // Draw vertical line before tax section
                doc.line(xPosition, startY, xPosition, startY + headerHeight);

                // Rate subheader
                doc.text('Rate', xPosition + halfWidth / 2, startY + headerHeight / 2, { align: 'center' });
                xPosition += halfWidth;

                // Vertical line between Rate and Amt
                doc.line(xPosition, startY, xPosition, startY + headerHeight);

                // Amt subheader
                doc.text('Amt.', xPosition + halfWidth / 2, startY + headerHeight / 2, { align: 'center' });
                xPosition += halfWidth;
            });

            // Total Value column
            doc.line(xPosition, startY, xPosition, startY + headerHeight);
            doc.text(mainHeaders[15], xPosition + mergedWidths[15] / 2, startY + headerHeight / 2, { align: 'center' });

            return startY + headerHeight;
        };

        // Full-Width Title with Bordered Box
        doc.setFontSize(18);
        doc.setTextColor(0, 0, 0);
        const titleText = 'TAX INVOICE';
        doc.rect(margin, yPosition, pageWidth - margin * 2, 12);
        doc.setFillColor(249, 249, 249);
        doc.rect(margin, yPosition, pageWidth - margin * 2, 12, 'F');
        doc.setFont('helvetica', 'bold');
        doc.text(titleText, pageWidth / 2, yPosition + 8, { align: 'center' });
        yPosition += 20;

        // Information Section Layout
        doc.setFontSize(10);
        const leftSectionWidth = (pageWidth - margin * 2) * (2 / 3);
        const rightSectionWidth = (pageWidth - margin * 2) * (1 / 3);

        // Top row - Consignor Bill From, Ship From, and Invoice Info
        const topBlockHeight = 40;
        let xPosition = margin;
        const topBlockWidth = leftSectionWidth / 2;

        // Consignor Bill From
        doc.rect(xPosition, yPosition, topBlockWidth, topBlockHeight);
        doc.setFont('helvetica', 'bold');
        doc.text('Consignor Bill From :-', xPosition + 2, yPosition + 5);
        doc.setFont('helvetica', 'normal');
        let tempY = yPosition + 10;
        doc.text(this.consignorName || 'N/A', xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorAddress || ''}`, xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorCity || ''}, ${this.consignorState || ''} - ${this.consignorPinCode || ''}`, xPosition + 2, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorGstNumber || 'N/A'}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorPanNumber || 'N/A'}`, xPosition + 20, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`DL No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorDLNumber || 'N/A'}`, xPosition + 17, tempY);

        // Consignor Ship From
        xPosition += topBlockWidth;
        doc.rect(xPosition, yPosition, topBlockWidth, topBlockHeight);
        doc.setFont('helvetica', 'bold');
        doc.text('Consignor Ship From:-', xPosition + 2, yPosition + 5);
        doc.setFont('helvetica', 'normal');
        tempY = yPosition + 10;
        doc.text(this.consignorName || 'N/A', xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorShipAddress || ''}`, xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorShipCity || ''}, ${this.consignorShipState || ''} - ${this.consignorShipPinCode || ''}`, xPosition + 2, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorGstNumber || 'N/A'}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorPanNumber || 'N/A'}`, xPosition + 21, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`DL No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorDLNumber || 'N/A'}`, xPosition + 18, tempY);

        // Invoice Information Section (Right side)
        xPosition = margin + leftSectionWidth;
        doc.rect(xPosition, yPosition, rightSectionWidth, topBlockHeight);
        doc.setFont('helvetica', 'bold');
        tempY = yPosition + 4;
        doc.text(`INVOICE NO./DATE`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        tempY += 4;
        doc.text(`INVOICE NO. :-`, xPosition + 2, tempY);
        doc.text(`${this.invoiceNumber || 'N/A'}`, xPosition + 28, tempY);
        tempY += 4;
        doc.text(`INVOICE DATE :-`, xPosition + 2, tempY);
        doc.text(`${this.invoiceDate || 'N/A'}`, xPosition + 31, tempY);
        tempY += 4;
        doc.text(`INVOICE DUE DATE :-`, xPosition + 2, tempY);
        doc.text(`${this.invoiceDueDate || 'N/A'}`, xPosition + 38, tempY);
        tempY += 4;
        doc.text(`Easy Bill No/Date:`, xPosition + 2, tempY);
        tempY += 6;
        doc.text(`Payment Terms:`, xPosition + 2, tempY);
        doc.text(`${this.paymentTerm || 'N/A'}`, xPosition + 28, tempY);
        tempY += 4;

        yPosition += topBlockHeight;

        // Bottom row - Consignee sections
        const bottomBlockHeight = 35;
        xPosition = margin;

        // Consignee Bill To
        doc.rect(xPosition, yPosition, topBlockWidth, bottomBlockHeight);
        doc.setFont('helvetica', 'bold');
        doc.text('Consignee Bill To :-', xPosition + 2, yPosition + 5);
        doc.setFont('helvetica', 'normal');
        tempY = yPosition + 9;
        doc.text(this.consigneeName || 'N/A', xPosition + 2, tempY);
        tempY += 4;
        doc.text(this.consigneeAddress || '', xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consigneeCity || ''}, ${this.consigneeState || ''} - ${this.consigneePinCode || ''}`, xPosition + 2, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneeGstNumber || 'N/A'}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneePanNumber || 'N/A'}`, xPosition + 21, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`DL No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneeDLNumber || 'N/A'}`, xPosition + 18, tempY);

        // Consignee Ship To
        xPosition += topBlockWidth;
        doc.rect(xPosition, yPosition, topBlockWidth, bottomBlockHeight);
        doc.setFont('helvetica', 'bold');
        doc.text('Consignee Ship To :-', xPosition + 2, yPosition + 5);
        doc.setFont('helvetica', 'normal');
        tempY = yPosition + 9;
        doc.text(this.consigneeName || 'N/A', xPosition + 2, tempY);
        tempY += 4;
        doc.text(this.consigneeShipAddress || '', xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consigneeShipCity || ''}, ${this.consigneeShipState || ''} - ${this.consigneeShipPinCode || ''}`, xPosition + 2, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneeGstNumber || 'N/A'}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneePanNumber || 'N/A'}`, xPosition + 21, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`DL No. :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneeDLNumber || 'N/A'}`, xPosition + 18, tempY);

        // Implant Details Section (Right side)
        xPosition = margin + leftSectionWidth;
        doc.rect(xPosition, yPosition, rightSectionWidth, bottomBlockHeight);
        doc.setFont('helvetica', 'bold');
        tempY = yPosition + 4;
        doc.text(`IMPLANT DETAILS`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        tempY += 4;
        doc.text(`Patient Name :`, xPosition + 2, tempY);
        doc.text(`${this.patientName || 'N/A'}`, xPosition + 28, tempY);
        tempY += 4;
        doc.text(`Age :`, xPosition + 2, tempY);
        doc.text(`${this.patientAge || 'N/A'}`, xPosition + 13, tempY);
        tempY += 4;
        doc.text(`Gender : ${this.patientGender || 'N/A'} `, xPosition + 2, tempY);
        tempY += 4;
        doc.text(`Date Of Implant :`, xPosition + 2, tempY);
        doc.text(`'N/A'`, xPosition + 34, tempY);
        tempY += 4;
        doc.text(`IP number :`, xPosition + 2, tempY);
        doc.text(`${this.ipNumber || 'N/A'}`, xPosition + 28, tempY);
        tempY += 4;
        doc.text(`CATH number :`, xPosition + 2, tempY);
        doc.text(`${this.cathNumber || 'N/A'}`, xPosition + 28, tempY);
        tempY += 4;
        doc.text(`Scheme :`, xPosition + 2, tempY);
        doc.text(`${this.scheme || 'N/A'}`, xPosition + 28, tempY);

        yPosition += bottomBlockHeight + 5;

        // Transport Information Row
        const infoRowHeight = 12;
        const printableWidth = pageWidth - margin * 2;
        doc.setFillColor(248, 248, 248);
        doc.rect(margin, yPosition, printableWidth, infoRowHeight, 'F');
        doc.rect(margin, yPosition, printableWidth, infoRowHeight);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8);

        const infoSections = [
            { label: 'Pre carriage by', value: 'By Road' },
            { label: 'Country Of Origin Of Goods:', value: 'INDIA' },
            { label: 'Destination', value: this.consigneeCity || '' },
            { label: 'Dispatched From Place:', value: this.consignorCity || '' },
            { label: 'Dispatched From State:', value: this.consignorState || '' },
            { label: 'Place Of Supply:', value: this.consigneeCity || '' },
            { label: 'State of Supply:', value: this.consigneeState || '' }
        ];

        const sectionWidth = printableWidth / infoSections.length;
        infoSections.forEach((section, index) => {
            const sectionX = margin + (index * sectionWidth);
            doc.setFont('helvetica', 'bold');
            doc.text(section.label, sectionX + 1, yPosition + 4);
            doc.setFont('helvetica', 'normal');
            doc.text(section.value, sectionX + 1, yPosition + 8);
        });

        yPosition += infoRowHeight ;

        // Table Section - Modified to conditionally show headers and table
        // if (!Array.isArray(this.invoiceItems) || this.invoiceItems.length === 0) {
        //     // No headers, no table - just show the no data message
        //     doc.setFontSize(10);
        //     doc.text('No line items available to display.', margin, yPosition + 5);
        //     yPosition += 15;
        // }
        if (!Array.isArray(this.invoiceItems) || this.invoiceItems.length === 0) {
            // No headers, no table - just show the no data message
            doc.setFontSize(10);
            doc.text('No line items available to display.', margin, yPosition + 5);
            yPosition += 15;
        }
        else {
            // const mergedWidths = [
            //     12, 25, 12, 12, 30, 15, 15, 12, 12, 12, 18, 18, 22, 22, 22, 15
            // ];
            const mergedWidths = [
        12, 25, 12, 12, 30, 15, 15, 12, 12, 12, 18, 18, 22, 22, 22, 15
    ];

            // Draw initial table headers
            yPosition = drawTableHeaders(yPosition);

            // Table data rows
            const rowHeight = 12;
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(7);

            this.invoiceItems.forEach((item, rowIndex) => {
                // Check if we need a new page (leave space for totals and footer)
                if (yPosition > pageHeight - 80) {
                    doc.addPage();
                    yPosition = 20;
                    // Redraw headers on new page
                    yPosition = drawTableHeaders(yPosition);
                }

                // Updated rowData without Unit Price
                const rowData = [
                    item.id?.toString() || '',
                    item.productName || '',
                    item.diameter || '',
                    item.length || '',
                    item.description || '',
                    item.batchNumber || '',
                    item.serialNumber || '',
                    item.mfgDate || '',
                    item.expiryDate || '',
                    item.hsn || '',
                    item.totalBeforeTax?.toString() || '0.00',
                    10, // Taxable value
                    (item.cgstRate || 0) + '%',
                    (item.cgst || 0),
                    (item.sgstRate || 0) + '%',
                    (item.sgst || 0),
                    (item.igstRate || 0) + '%',
                    (item.igst || 0),
                    (item.netAmount || 0)
                ];

                // Alternate row coloring
                if (rowIndex % 2 === 0) {
                    doc.setFillColor(248, 248, 248);
                } else {
                    doc.setFillColor(255, 255, 255);
                }

                doc.rect(margin, yPosition, printableWidth, rowHeight, 'F');
                doc.rect(margin, yPosition, printableWidth, rowHeight);

                xPosition = margin;

                // Regular columns (0-11, excluding Unit Price)
                for (let i = 0; i < 12; i++) {
                    const maxWidth = mergedWidths[i] - 2;
                    const splitText = doc.splitTextToSize(rowData[i].toString(), maxWidth);
                    const displayText = splitText[0];
                    doc.text(displayText, xPosition + mergedWidths[i] / 2, yPosition + rowHeight / 2, { align: 'center' });

                    if (i > 0) {
                        doc.line(xPosition, yPosition, xPosition, yPosition + rowHeight);
                    }
                    xPosition += mergedWidths[i];
                }

                // Tax columns with Rate/Amt subdivisions
                const taxColumns = ['CGST', 'SGST', 'IGST'];
                taxColumns.forEach((taxType, taxIndex) => {
                    const taxWidth = mergedWidths[12 + taxIndex]; // Updated index
                    const halfWidth = taxWidth / 2;

                    // Rate
                    const rateIndex = 12 + (taxIndex * 2);
                    doc.text(rowData[rateIndex], xPosition + halfWidth / 2, yPosition + rowHeight / 2, { align: 'center' });
                    doc.line(xPosition, yPosition, xPosition, yPosition + rowHeight);
                    xPosition += halfWidth;

                    // Amount
                    const amtIndex = 13 + (taxIndex * 2);
                    doc.text(rowData[amtIndex], xPosition + halfWidth / 2, yPosition + rowHeight / 2, { align: 'center' });
                    doc.line(xPosition, yPosition, xPosition, yPosition + rowHeight);
                    xPosition += halfWidth;
                });

                // Total Value
                doc.text(rowData[18], xPosition + mergedWidths[15] / 2, yPosition + rowHeight / 2, { align: 'center' });

                yPosition += rowHeight;
            });

            // Total row
            const totalRowHeight = 12;
            doc.setFillColor(240, 240, 240);
            doc.rect(margin, yPosition, printableWidth, totalRowHeight, 'F');
            doc.rect(margin, yPosition, printableWidth, totalRowHeight);

            xPosition = margin;
            doc.setFont('helvetica', 'bold');

            // "TOTAL" label spanning first 11 columns (reduced from 12)
            let totalLabelWidth = 0;
            for (let i = 0; i < 11; i++) {
                totalLabelWidth += mergedWidths[i];
            }
            doc.text('TOTAL', xPosition + totalLabelWidth / 2, yPosition + totalRowHeight / 2, { align: 'center' });
            doc.line(xPosition + totalLabelWidth, yPosition, xPosition + totalLabelWidth, yPosition + totalRowHeight);
            xPosition += totalLabelWidth;

            // Total taxable value (column 11, was 12)
            doc.text((this.totalAmount || 0).toFixed(2), xPosition + mergedWidths[11] / 2, yPosition + totalRowHeight / 2, { align: 'center' });
            xPosition += mergedWidths[11];

            // Tax totals (starting from column 12, was 13)
            const taxTotals = [this.totalCGSTAmount, this.totalSGSTAmount, this.totalIGSTAmount];
            const taxColumns = ['CGST', 'SGST', 'IGST'];
            taxColumns.forEach((taxType, taxIndex) => {
                const taxWidth = mergedWidths[12 + taxIndex]; // Updated index
                doc.text((taxTotals[taxIndex] || 0).toFixed(2), xPosition + taxWidth / 2, yPosition + totalRowHeight / 2, { align: 'center' });
                doc.line(xPosition, yPosition, xPosition, yPosition + totalRowHeight);
                xPosition += taxWidth;
            });

            // Final total (last column)
            const finalTotal = (this.totalAmount || 0) + (this.totalCGSTAmount || 0) + (this.totalSGSTAmount || 0) + (this.totalIGSTAmount || 0);
            doc.text(finalTotal.toFixed(2), xPosition + mergedWidths[15] / 2, yPosition + totalRowHeight / 2, { align: 'center' });

            yPosition += totalRowHeight + 5;
        }


        // Check if we need a new page for footer content
        if (yPosition > pageHeight - 80) {
            doc.addPage();
            yPosition = 20;
        }

        // Amount in Words
        doc.setFontSize(10);
        doc.setFont('helvetica', 'bold');
        doc.text(`Amount (In Words) : ${this.amountInWords || 'N/A'}`, margin, yPosition + 4);
        doc.setFont('helvetica', 'normal');
        doc.text('All the products inspected are STERILE.', margin, yPosition + 8);
        yPosition += 20;

        // Footer Section
        const footerHeight = 60;
        const footerWidth = pageWidth - margin * 2;
        const footerLeftWidth = footerWidth * 0.7;
        const footerRightWidth = footerWidth * 0.3;

        doc.rect(margin, yPosition, footerWidth, footerHeight);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8);

        let termsY = yPosition + 4;
        const terms = [
            { text: 'Terms And Conditions:- ', bold: true },
            { text: 'Comments:', bold: true },
            { text: this.comments || '', bold: false },
            { text: 'Payment Terms:', bold: true },
            { text: 'Payment will be received FREE and not against goods bills.', bold: false },
            { text: 'Shipping Instructions:', bold: true },
            { text: 'Avoid Exposure to direct sunlight or heaters & keep the products in a clean, organized, cool and dry place.', bold: false },
            { text: 'Subject to Ahmedabad Jurisdiction.', bold: false },
            { text: 'Our responsibility ceases once the goods leave our premises.', bold: false },
            { text: 'Claim for any loss in the consignment should be settled by the buyer directly with the carrier.', bold: false },
            { text: 'Buyer\'s Responsibility cover once the goods leave our premises.', bold: false },
            { text: 'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct EACE', bold: false }
        ];

        terms.forEach((term, index) => {
            if (term.bold) {
                doc.setFont('helvetica', 'bold');
            } else {
                doc.setFont('helvetica', 'normal');
            }
            const splitText = doc.splitTextToSize(term.text, footerLeftWidth - 4);
            doc.text(splitText, margin + 2, termsY);
            termsY += splitText.length * 3;
        });

        // Signature section
        doc.line(margin + footerLeftWidth, yPosition, margin + footerLeftWidth, yPosition + footerHeight);
        const signatureX = margin + footerLeftWidth;
        const signatureWidth = footerRightWidth;
        const signatureHeight = footerHeight / 2;

        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.text('Receiver Signature', signatureX + signatureWidth / 2, yPosition + 15, { align: 'center' });
        doc.line(signatureX, yPosition + signatureHeight, signatureX + signatureWidth, yPosition + signatureHeight);
        doc.text('Authorised Signatory:', signatureX + signatureWidth / 2, yPosition + signatureHeight + 15, { align: 'center' });

        const fileName = `Tax_Invoice_${this.invoiceNumber || 'Document'}.pdf`;
        doc.save(fileName);

        this.showToast('Success', 'Tax Invoice PDF downloaded successfully!', 'success');
    }


}