import { LightningElement, wire, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jsPDFResource from '@salesforce/resourceUrl/jspdf';
import getDeliveryChallanDetails from '@salesforce/apex/DeliveryChallanController.getDeliveryChallanDetails';
import recordType from '@salesforce/apex/DeliveryChallanController.getRecordType';

export default class DCDownloadPage extends LightningElement {
    @api recordId;

    deliveryChallan;
    error;
    jsPDFLoaded = false;
    hospitalRecType;

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

    // consignee ship details
    consigneeShipAddress;
    consigneeShipCity;
    consigneeShipState;
    consigneeShipPinCode;

    // Dispatch and Supply Info
    dispatchFromPlace;
    dispatchFromState;
    placeOfSupply;
    stateOfSupply;

    // Line Items
    deliveryChallanLineItems = [];

    // Total information for table
    totalCGSTAmount = 0;
    totalSGSTAmount = 0;
    totalIGSTAmount = 0;
    totalCGSTRate = 0;
    totalSGSTRate = 0;
    totalIGSTRate = 0;
    totalTaxableValue = 0;
    totalFinalValue = 0;

    // Amount in words
    amountInWords = '';

    // Courier Details
    courierName;
    courierDocketNumber;

    // Order Info
    supplyOrderNumber;
    supplyOrderDate;
    deliveryChallanNumber;
    deliveryChallanDate;

    consignorWarehouse;
    consigneeWarehouse;

    comment;

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

    // // Helper method to reset totals
    resetTotals() {
        this.totalCGSTAmount = 0;
        this.totalSGSTAmount = 0;
        this.totalIGSTAmount = 0;
        this.totalTaxableValue = 0;
        this.totalFinalValue = 0;
    }

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

    @wire(getDeliveryChallanDetails, { recordId: '$recordId' })
    wiredDeliveryChallan({ error, data }) {
        if (data) {
            this.deliveryChallan = data.deliveryChallan;
            this.consigneeWarehouse = data.consigneeWarehouses[0];
            this.consignorWarehouse = data.consignorWarehouses[0];
            this.error = undefined;
            console.log('Delivery Challan Data:', JSON.stringify(this.deliveryChallan));

            console.log('consignor Warehouse: ', JSON.stringify(this.consignorWarehouse));
            console.log('consignee Warehouse: ', JSON.stringify(this.consigneeWarehouse));

            // Reset totals before calculation
            this.resetTotals();

            // Handle empty data case - create default structure
            if (!this.deliveryChallan) {
                this.deliveryChallan = this.createDefaultDeliveryChallanStructure();
            }

            // Courier Details
            this.courierName = this.deliveryChallan.Courier_Name__c || 'Not Available';
            this.courierDocketNumber = this.deliveryChallan.Courier_Docket_No__c || 'Not Available';

            // Consignor Details - Create default if not exists
            const consignor = this.deliveryChallan.Consignor_Distributor__r || this.createDefaultAccountStructure();
            this.consignorName = consignor.Name || 'Not Available';
            this.consignorAddress = consignor.Address__c || 'Not Available';
            this.consignorCity = consignor.City__c || 'Not Available';
            this.consignorState = consignor.State__c || 'Not Available';
            this.consignorPinCode = consignor.Account_Pin_Code__c || 'Not Available';
            this.consignorPanNumber = consignor.PAN_Number__c || 'Not Available';
            this.consignorGstNumber = consignor.GST_Number__c || 'Not Available';
            this.consignorDLNumber = consignor.Drug_Licence_Number__c || 'Not Available';
            console.log('Consignor Details:', JSON.stringify(consignor));

            this.comment = this.deliveryChallan.Comment__c || 'Not Available';

            if (this.hospitalRecType === 'HDC') {
                const consigneeHospital = this.deliveryChallan.Consignee_Hospital__r || {};

                this.consigneeName = consigneeHospital.Name || 'Not Available';
                this.consigneeAddress = consigneeHospital.Address__c || 'Not Available';
                this.consigneeCity = consigneeHospital.City__c || 'Not Available';
                this.consigneeState = consigneeHospital.State__c || 'Not Available';
                this.consigneePinCode = consigneeHospital.Account_Pin_Code__c || 'Not Available';
                this.consigneePanNumber = consigneeHospital.PAN_Number__c || 'Not Available';
                this.consigneeGstNumber = consigneeHospital.GST_Number__c || 'Not Available';
                this.consigneeDLNumber = consigneeHospital.DL_no__c || 'Not Available';

            } else {
                // Consignee Details - Create default if not exists
                const consignee = this.deliveryChallan.Consignee_Distributor__r || this.createDefaultAccountStructure();
                this.consigneeName = consignee.Name || 'Not Available';
                this.consigneeAddress = consignee.Address__c || 'Not Available';
                this.consigneeCity = consignee.City__c || 'Not Available';
                this.consigneeState = consignee.State__c || 'Not Available';
                this.consigneePinCode = consignee.Account_Pin_Code__c || 'Not Available';
                this.consigneePanNumber = consignee.PAN_Number__c || 'Not Available';
                this.consigneeGstNumber = consignee.GST_Number__c || 'Not Available';
                this.consigneeDLNumber = consignee.Drug_Licence_Number__c || 'Not Available';
                console.log('Consignee Details:', JSON.stringify(consignee));

                // consignee ship address
                this.consigneeShipAddress = this.consigneeWarehouse.Address__c || 'Not Available';
                this.consigneeShipCity = this.consigneeWarehouse.City__c || 'Not Available';
                this.consigneeShipPinCode = this.consigneeWarehouse.ZipCode__c || 'Not Available';
                this.consigneeShipState = this.consigneeWarehouse.State__c || 'Not Available';
            }

            // Order Info
            this.deliveryChallanNumber = this.deliveryChallan.Name || 'Not Available';
            this.deliveryChallanDate = this.formatDate(this.deliveryChallan.DC_Generated_Date__c) || 'Not Available';

            // Supply Order with default structure
            const supplyOrder = this.deliveryChallan.Supply_Order__r || this.createDefaultSupplyOrderStructure();
            this.supplyOrderNumber = supplyOrder.Name || 'Not Available';
            this.supplyOrderDate = this.formatDate(supplyOrder.CreatedDate) || 'Not Available';

            // Consignor Ship
            this.consignorShipAddress = this.consignorWarehouse.Address__c || 'Not Available';
            this.consignorShipState = this.consignorWarehouse.State__c || 'Not Available';
            this.consignorShipCity = this.consignorWarehouse.City__c || 'Not Available';
            this.consignorShipPinCode = this.consignorWarehouse.ZipCode__c || 'Not Available';



            // Place of dispatch and supply
            this.placeOfSupply = this.consigneeShipCity || 'Not Available';
            this.stateOfSupply = this.consigneeShipState || 'Not Available';

            // Dispatch
            this.dispatchFromPlace = this.consignorShipCity || 'Not Available';
            this.dispatchFromState = this.consignorShipState || 'Not Available';

            this.deliveryChallanLineItems = [];
            let counter = 1;

            // Process DC Products - Handle empty array
            const dcProducts = this.deliveryChallan.DC_Products__r || [];
            if (dcProducts.length === 0) {
                // Create a default line item when no products exist
                this.deliveryChallanLineItems.push(this.createDefaultLineItem(counter));

                // Set default ship from details
                this.consignorShipAddress = 'Not Available';
                this.consignorShipCity = 'Not Available';
                this.consignorShipState = 'Not Available';
                this.consignorShipPinCode = 'Not Available';
                this.dispatchFromPlace = 'Not Available';
                this.dispatchFromState = 'Not Available';
            } else {
                dcProducts.forEach(product => {
                    const zydusProduct = product.Zydus_Product__r || this.createDefaultZydusProductStructure();
                    const zydusProductName = zydusProduct.Name || 'Not Available';
                    const dia = zydusProduct.Diameter__c || 'Not Available';
                    const length = zydusProduct.Length__c || 'Not Available';
                    const description = zydusProduct.Description__c || 'Not Available';

                    // Process Line Items - Handle empty array
                    const lineItems = product.Delivery_Challan_Line_Items__r || [];
                    if (lineItems.length === 0) {
                        // Create default line item if no line items exist
                        const defaultItem = this.createDefaultLineItem(counter);
                        defaultItem.productName = zydusProductName;
                        defaultItem.dia = dia;
                        defaultItem.length = length;
                        defaultItem.description = description;
                        this.deliveryChallanLineItems.push(defaultItem);
                        counter++;
                    } else {
                        lineItems.forEach(item => {
                            const warehouse = item.Warehouse__r || this.createDefaultWarehouseStructure();

                            // Set ship from details from first warehouse
                            // if (counter === 1) {
                            //     this.consignorShipAddress = warehouse.Address__c || 'Not Available';
                            //     this.consignorShipCity = warehouse.City__c || 'Not Available';
                            //     this.consignorShipState = warehouse.State__c || 'Not Available';
                            //     this.consignorShipPinCode = warehouse.ZipCode__c || 'Not Available';

                            //     this.dispatchFromPlace = warehouse.City__c || 'Not Available';
                            //     this.dispatchFromState = warehouse.State__c || 'Not Available';
                            // }

                            // Calculate amounts
                            const taxableValue = parseFloat(item.Unit_Price__c) || 0;
                            const cgst = parseFloat(item.CGST__c) || 0;
                            const sgst = parseFloat(item.SGST__c) || 0;
                            const igst = parseFloat(item.IGST__c) || 0;
                            const netAmount = parseFloat(item.Net_Amount__c) || 0;
                            const quantity = parseFloat(item.Quantity__c) || 0;

                            // Add to totals
                            this.totalCGSTAmount += cgst;
                            this.totalSGSTAmount += sgst;
                            this.totalIGSTAmount += igst;
                            this.totalTaxableValue += taxableValue;
                            this.totalFinalValue += netAmount;

                            // Calculate tax rates
                            const cgstRate = taxableValue > 0 ? (cgst / taxableValue) * 100 : 0;
                            const sgstRate = taxableValue > 0 ? (sgst / taxableValue) * 100 : 0;
                            const igstRate = taxableValue > 0 ? (igst / taxableValue) * 100 : 0;

                            this.deliveryChallanLineItems.push({
                                id: counter++,
                                suDCNumber: item.Name || 'Not Available',
                                productName: zydusProductName,
                                dia: dia,
                                length: length,
                                description: description,
                                batchNumber: item.Batch_Number__c || 'Not Available',
                                serialNumber: item.Serial_Number__c || 'Not Available',
                                mfgDate: this.formatDate(item.Manufacturing_Date__c) || 'Not Available',
                                expiryDate: this.formatDate(item.Expiry_Date__c) || 'Not Available',
                                hsn: item.HSN_Code__r.Name || 'Not Available',
                                // quantity: quantity,
                                taxableValue: taxableValue.toFixed(2),
                                CGSTAmount: cgst.toFixed(2),
                                SGSTAmount: sgst.toFixed(2),
                                IGSTAmount: igst.toFixed(2),
                                CGSTRate: this.formatRate(cgstRate),
                                SGSTRate: this.formatRate(sgstRate),
                                IGSTRate: this.formatRate(igstRate),
                                totalValue: netAmount.toFixed(2)
                            });
                        });
                    }
                });
            }

            // Calculate total tax rates
            // this.totalCGSTRate = this.totalTaxableValue > 0 ?
            //     this.formatRate((this.totalCGSTAmount / this.totalTaxableValue) * 100) : 0;
            // this.totalSGSTRate = this.totalTaxableValue > 0 ?
            //     this.formatRate((this.totalSGSTAmount / this.totalTaxableValue) * 100) : 0;
            // this.totalIGSTRate = this.totalTaxableValue > 0 ?
            //     this.formatRate((this.totalIGSTAmount / this.totalTaxableValue) * 100) : 0;

            this.totalCGSTRate = this.deliveryChallanLineItems.reduce((sum, item) => sum + parseFloat(item.CGSTRate || 0), 0).toFixed(2);
            this.totalSGSTRate = this.deliveryChallanLineItems.reduce((sum, item) => sum + parseFloat(item.SGSTRate || 0), 0).toFixed(2);
            this.totalIGSTRate = this.deliveryChallanLineItems.reduce((sum, item) => sum + parseFloat(item.IGSTRate || 0), 0).toFixed(2);

            // Format totals
            this.totalTaxableValue = this.totalTaxableValue.toFixed(2);
            this.totalCGSTAmount = this.totalCGSTAmount.toFixed(2);
            this.totalSGSTAmount = this.totalSGSTAmount.toFixed(2);
            this.totalIGSTAmount = this.totalIGSTAmount.toFixed(2);
            this.totalFinalValue = this.totalFinalValue.toFixed(2);

            // Convert amount to words
            this.amountInWords = this.convertNumberToWords(this.totalFinalValue);

            console.log('Delivery Challan Line Items:', JSON.stringify(this.deliveryChallanLineItems));
        } else if (error) {
            this.error = error;
            this.deliveryChallan = undefined;
            console.error('Error:', error);

            // Create default structure even on error
            this.createDefaultDataOnError();
        }
    }

    // Helper method to create default delivery challan structure
    createDefaultDeliveryChallanStructure() {
        return {
            Name: 'Not Available',
            Courier_Name__c: 'Not Available',
            Courier_Docket_No__c: 'Not Available',
            DC_Generated_Date__c: null,
            Consignor_Distributor__r: this.createDefaultAccountStructure(),
            Consignee_Distributor__r: this.createDefaultAccountStructure(),
            Supply_Order__r: this.createDefaultSupplyOrderStructure(),
            DC_Products__r: []
        };
    }

    // Helper method to create default account structure
    createDefaultAccountStructure() {
        return {
            Name: 'Not Available',
            Address__c: 'Not Available',
            City__c: 'Not Available',
            State__c: 'Not Available',
            Account_Pin_Code__c: 'Not Available',
            PAN_Number__c: 'Not Available',
            GST_Number__c: 'Not Available',
            Drug_Licence_Number__c: 'Not Available'
        };
    }

    // Helper method to create default supply order structure
    createDefaultSupplyOrderStructure() {
        return {
            Name: 'Not Available',
            CreatedDate: null
        };
    }

    // Helper method to create default zydus product structure
    createDefaultZydusProductStructure() {
        return {
            Name: 'Not Available',
            Diameter__c: 'Not Available',
            Length__c: 'Not Available',
            Description__c: 'Not Available'
        };
    }

    // Helper method to create default warehouse structure
    createDefaultWarehouseStructure() {
        return {
            Address__c: 'Not Available',
            City__c: 'Not Available',
            State__c: 'Not Available',
            ZipCode__c: 'Not Available'
        };
    }

    // Helper method to create default line item
    createDefaultLineItem(id) {
        return {
            id: id,
            suDCNumber: 'Not Available',
            productName: 'Not Available',
            dia: 'Not Available',
            length: 'Not Available',
            description: 'Not Available',
            batchNumber: 'Not Available',
            serialNumber: 'Not Available',
            mfgDate: 'Not Available',
            expiryDate: 'Not Available',
            hsn: 'Not Available',
            quantity: 0,
            taxableValue: '0.00',
            CGSTAmount: '0.00',
            SGSTAmount: '0.00',
            IGSTAmount: '0.00',
            CGSTRate: 0,
            SGSTRate: 0,
            IGSTRate: 0,
            totalValue: '0.00'
        };
    }

    // Helper method to create default data structure on error
    createDefaultDataOnError() {
        // Set all properties to default values
        this.courierName = 'Not Available';
        this.courierDocketNumber = 'Not Available';

        // Consignor Details
        this.consignorName = 'Not Available';
        this.consignorAddress = 'Not Available';
        this.consignorCity = 'Not Available';
        this.consignorState = 'Not Available';
        this.consignorPinCode = 'Not Available';
        this.consignorPanNumber = 'Not Available';
        this.consignorGstNumber = 'Not Available';
        this.consignorDLNumber = 'Not Available';

        // Consignor Ship From
        this.consignorShipAddress = 'Not Available';
        this.consignorShipCity = 'Not Available';
        this.consignorShipState = 'Not Available';
        this.consignorShipPinCode = 'Not Available';

        // Consignee Details
        this.consigneeName = 'Not Available';
        this.consigneeAddress = 'Not Available';
        this.consigneeCity = 'Not Available';
        this.consigneeState = 'Not Available';
        this.consigneePinCode = 'Not Available';
        this.consigneePanNumber = 'Not Available';
        this.consigneeGstNumber = 'Not Available';
        this.consigneeDLNumber = 'Not Available';

        // Dispatch and Supply Info
        this.dispatchFromPlace = 'Not Available';
        this.dispatchFromState = 'Not Available';
        this.placeOfSupply = 'Not Available';
        this.stateOfSupply = 'Not Available';

        // Order Info
        this.supplyOrderNumber = 'Not Available';
        this.supplyOrderDate = 'Not Available';
        this.deliveryChallanNumber = 'Not Available';
        this.deliveryChallanDate = 'Not Available';

        // Create default line item
        this.deliveryChallanLineItems = [this.createDefaultLineItem(1)];

        // Set totals to zero
        this.resetTotals();
        this.totalTaxableValue = '0.00';
        this.totalCGSTAmount = '0.00';
        this.totalSGSTAmount = '0.00';
        this.totalIGSTAmount = '0.00';
        this.totalFinalValue = '0.00';

        // Amount in words
        this.amountInWords = 'RUPEES ZERO AND ZERO PAISA ONLY';
    }

    // Helper method to format rates to 2 decimal places
    formatRate(rate) {
        return Math.round(rate * 100) / 100;
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        try {
            const date = new Date(dateStr);
            if (isNaN(date.getTime())) return '';

            const day = String(date.getDate()).padStart(2, '0');
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const year = date.getFullYear();
            return `${day}/${month}/${year}`;
        } catch (e) {
            console.error('Date formatting error:', e);
            return '';
        }
    }

    convertNumberToWords(amount) {
        if (!amount || amount === 0) return "RUPEES ZERO AND ZERO PAISA ONLY";

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

        const convertToWords = (num) => {
            if (num === 0) return "ZERO";

            let result = "";

            const crore = Math.floor(num / 10000000);
            const lakh = Math.floor((num % 10000000) / 100000);
            const thousand = Math.floor((num % 100000) / 1000);
            const hundred = Math.floor((num % 1000) / 100);
            const rest = num % 100;

            if (crore) result += `${convertToWords(crore)} CRORE `;
            if (lakh) result += `${convertToWords(lakh)} LAKH `;
            if (thousand) result += `${convertToWords(thousand)} THOUSAND `;
            if (hundred) result += `${ones[hundred]} HUNDRED `;

            if (rest && result !== "") result += "AND ";
            result += getWords(rest);

            return result.trim();
        };

        try {
            const rupees = Math.floor(amount);
            const paisa = Math.round((amount - rupees) * 100);

            const rupeesWords = convertToWords(rupees);
            const paisaWords = paisa > 0 ? `${convertToWords(paisa)} PAISA` : "ZERO PAISA";

            return `RUPEES ${rupeesWords} AND ${paisaWords} ONLY`;
        } catch (e) {
            console.error('Amount to words conversion error:', e);
            return "RUPEES ZERO AND ZERO PAISA ONLY";
        }
    }

    async handleDownloadPDF() {
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

        let yPosition = 10;
        const pageWidth = doc.internal.pageSize.getWidth();
        const pageHeight = doc.internal.pageSize.getHeight();
        const margin = 10;

        // Set lighter border style for all elements
        doc.setLineWidth(0.5);
        doc.setDrawColor(150, 150, 150);

        // Company Name (Logo section)
        // doc.setFontSize(20);
        // doc.setFont('helvetica', 'bold');
        // doc.setTextColor(44, 90, 160);
        // doc.text(this.consignorName || 'N/A', margin, yPosition);
        // yPosition += 15;

        // Full-Width Title with Bordered Box
        doc.setFontSize(18);
        doc.setTextColor(0, 0, 0);
        const titleText = 'DELIVERY CHALLAN';
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

        // Top row - Consignor Bill From, Ship From, and Order Info
        const topBlockHeight = 55;
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
        doc.text(`${this.consignorAddress || ''},`, xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorCity || ''}, ${this.consignorState || ''} - ${this.consignorPinCode || ''}`, xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorState || ''} | INDIA`, xPosition + 2, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorGstNumber || ''}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorPanNumber || ''}`, xPosition + 15, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`DL No. :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorDLNumber || ''}`, xPosition + 18, tempY);

        // Consignor Ship From
        xPosition += topBlockWidth;
        doc.rect(xPosition, yPosition, topBlockWidth, topBlockHeight);
        doc.setFont('helvetica', 'bold');
        doc.text('Consignor Ship From :-', xPosition + 2, yPosition + 5);
        doc.setFont('helvetica', 'normal');
        tempY = yPosition + 10;
        doc.text(this.consignorName || 'N/A', xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorShipAddress || ''},`, xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorShipCity || ''}, ${this.consignorShipState || ''} - ${this.consignorShipPinCode || ''}`, xPosition + 2, tempY);
        tempY += 4;
        doc.text(`${this.consignorShipState || ''} | INDIA`, xPosition + 2, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorGstNumber || ''}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorPanNumber || ''}`, xPosition + 15, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`DL No. :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consignorDLNumber || ''}`, xPosition + 18, tempY);

        // Right side - Order Info
        xPosition = margin + leftSectionWidth;
        doc.rect(xPosition, yPosition, rightSectionWidth, topBlockHeight);
        doc.setFont('helvetica', 'bold');
        tempY = yPosition + 6;
        doc.text(`Delivery Challan No :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.deliveryChallanNumber || ''}`, xPosition + 40, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`Delivery Challan Date :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.deliveryChallanDate || ''}`, xPosition + 45, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`Eway Bill No & Date :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text('To be imported!', xPosition + 38, tempY);
        tempY += 6;
        // doc.setFont('helvetica', 'bold');
        // doc.text(`Exporter Ref. :-`, xPosition + 2, tempY);
        // doc.setFont('helvetica', 'normal');
        // doc.text('N/A', xPosition + 30, tempY);
        // tempY += 6;
        // doc.setFont('helvetica', 'bold');
        // doc.text(`I. E. CODE NO. :-`, xPosition + 2, tempY);
        // doc.setFont('helvetica', 'normal');
        // doc.text('N/A', xPosition + 30, tempY);
        // tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`Supply Order No :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.supplyOrderNumber || ''}`, xPosition + 35, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`Supply Order Date :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.supplyOrderDate || ''}`, xPosition + 38, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`Courier Name :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.courierName || ''}`, xPosition + 30, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`Courier Docket No :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.courierDocketNumber || ''}`, xPosition + 35, tempY);
        tempY += 6;
        doc.setFont('helvetica', 'bold');
        doc.text(`Comments :-`, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        const commentsLines = doc.splitTextToSize(`"Goods send on sale on approval basis" ${this.comment || ''}`, rightSectionWidth - 4);
        doc.text(commentsLines, xPosition + 2, tempY + 4);
        tempY += commentsLines.length * 3 + 5;

        yPosition += topBlockHeight;



        // Bottom row - Consignee sections
        const bottomBlockHeight = 26;
        xPosition = margin;

        // Consignee Bill To (First)
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
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneeGstNumber || ''}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneePanNumber || ''}`, xPosition + 15, tempY);

        // Consignee Bill To (Second)
        xPosition += topBlockWidth;
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
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`GSTIN No. :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneeGstNumber || ''}`, xPosition + 23, tempY);
        tempY += 4;
        doc.setFont('helvetica', 'bold');
        doc.text(`PAN :- `, xPosition + 2, tempY);
        doc.setFont('helvetica', 'normal');
        doc.text(`${this.consigneePanNumber || ''}`, xPosition + 15, tempY);

        yPosition += bottomBlockHeight + 10;

        // Table Section
        if (!Array.isArray(this.deliveryChallanLineItems) || this.deliveryChallanLineItems.length === 0) {
            doc.setFontSize(10);
            doc.text('No line items available to display.', margin, yPosition + 5);
            yPosition += 15;
        } else {
            const mainHeaders = [
                'Sr. No.', 'Sub Product No.', 'Product Name', 'Dia', 'Length', 'Description', 'Batch No', 'Sr. No',
                'Mfg. Date', 'Exp. Date', 'HSN', 'Taxable value', 'CGST Rate', 'CGST Amt.', 'SGST Rate',
                'SGST Amt.', 'IGST Rate', 'IGST Amt.', 'Total Value'
            ];

            // Calculate column widths - Fixed widths for better control
            const printableWidth = pageWidth - margin * 2;
            // const colWidths = [
            //     8,   // Sr. No.
            //     18,  // Sub Product No.
            //     25,  // Product Name
            //     8,   // Dia
            //     10,  // Length
            //     25,  // Description
            //     15,  // Batch No
            //     15,  // Sr. No
            //     12,  // Mfg. Date
            //     12,  // Exp. Date
            //     9,   // HSN
            //     8,   // Qty
            //     15,  // Taxable value
            //     12,  // CGST Rate
            //     13,  // CGST Amt.
            //     12,  // SGST Rate
            //     13,  // SGST Amt.
            //     12,  // IGST Rate
            //     12,  // IGST Amt.
            //     14   // Total Value
            // ];

            const colWidths = [
                8,   // Sr. No.
                20,  // Sub DC No.
                25,  // Product Name
                8,   // Dia
                10,  // Length
                27,  // Description
                16,  // Batch No
                16,  // Sr. No
                13,  // Mfg. Date
                13,  // Exp. Date
                9,   // HSN
                15,  // Taxable value (was index 12, now index 11)
                12,  // CGST Rate
                13,  // CGST Amt.
                12,  // SGST Rate
                13,  // SGST Amt.
                12,  // IGST Rate
                12,  // IGST Amt.
                14   // Total Value
            ];

            // First row - Transport and origin info
            xPosition = margin;
            const infoRowHeight = 12;
            doc.setFillColor(248, 248, 248);
            doc.rect(margin, yPosition, printableWidth, infoRowHeight, 'F');
            doc.rect(margin, yPosition, printableWidth, infoRowHeight);
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(8);

            const infoSections = [
                { label: 'Pre carriage by', value: 'By Road' },
                { label: 'Country Of Origin Of Goods', value: 'INDIA' },
                { label: 'Dispatch From Place', value: this.dispatchFromPlace || '' },
                { label: 'Dispatch From State', value: this.dispatchFromState || '' },
                { label: 'Place Of Supply', value: this.placeOfSupply || '' },
                { label: 'State of Supply', value: this.stateOfSupply || '' }
            ];

            const sectionWidth = printableWidth / infoSections.length;
            infoSections.forEach((section, index) => {
                const sectionX = margin + (index * sectionWidth);
                doc.setFont('helvetica', 'bold');
                doc.text(section.label, sectionX + 2, yPosition + 4);
                doc.setFont('helvetica', 'normal');
                doc.text(section.value, sectionX + 2, yPosition + 8);
            });

            yPosition += infoRowHeight;

            // Table headers
            const headerHeight = 15; // Increased header height
            doc.setFillColor(240, 240, 240);
            doc.rect(margin, yPosition, printableWidth, headerHeight, 'F');
            doc.rect(margin, yPosition, printableWidth, headerHeight);
            xPosition = margin;
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(6); // Smaller font for better fit

            mainHeaders.forEach((header, index) => {
                // Split long headers into multiple lines
                const maxWidth = colWidths[index] - 2;
                const splitHeader = doc.splitTextToSize(header, maxWidth);

                // Center the header text
                const textY = yPosition + headerHeight / 2;
                if (splitHeader.length === 1) {
                    doc.text(splitHeader[0], xPosition + colWidths[index] / 2, textY, { align: 'center' });
                } else {
                    // Multiple lines
                    const lineHeight = 3;
                    const startY = textY - (splitHeader.length - 1) * lineHeight / 2;
                    splitHeader.forEach((line, lineIndex) => {
                        doc.text(line, xPosition + colWidths[index] / 2, startY + lineIndex * lineHeight, { align: 'center' });
                    });
                }

                // Draw vertical lines
                if (index > 0) {
                    doc.line(xPosition, yPosition, xPosition, yPosition + headerHeight);
                }
                xPosition += colWidths[index];
            });
            yPosition += headerHeight;

            // Table data rows
            const rowHeight = 15; // Increased row height
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(6); // Smaller font for data

            this.deliveryChallanLineItems.forEach((item, rowIndex) => {
                if (yPosition > pageHeight - 60) {
                    doc.addPage();
                    yPosition = 20;

                    // Redraw headers on new page
                    doc.setFillColor(240, 240, 240);
                    doc.rect(margin, yPosition, printableWidth, headerHeight, 'F');
                    doc.rect(margin, yPosition, printableWidth, headerHeight);
                    xPosition = margin;
                    doc.setFont('helvetica', 'bold');
                    doc.setFontSize(6);

                    mainHeaders.forEach((header, index) => {
                        const maxWidth = colWidths[index] - 2;
                        const splitHeader = doc.splitTextToSize(header, maxWidth);
                        const textY = yPosition + headerHeight / 2;

                        if (splitHeader.length === 1) {
                            doc.text(splitHeader[0], xPosition + colWidths[index] / 2, textY, { align: 'center' });
                        } else {
                            const lineHeight = 3;
                            const startY = textY - (splitHeader.length - 1) * lineHeight / 2;
                            splitHeader.forEach((line, lineIndex) => {
                                doc.text(line, xPosition + colWidths[index] / 2, startY + lineIndex * lineHeight, { align: 'center' });
                            });
                        }

                        if (index > 0) {
                            doc.line(xPosition, yPosition, xPosition, yPosition + headerHeight);
                        }
                        xPosition += colWidths[index];
                    });
                    yPosition += headerHeight;
                    doc.setFont('helvetica', 'normal');
                    doc.setFontSize(6);
                }

                const rowData = [
                    item.id?.toString() || '',
                    item.suDCNumber || '', // Changed from subProductNumber to suDCNumber to match deliveryChallanLineItems
                    item.productName || '',
                    item.dia || '',
                    item.length || '',
                    item.description || '',
                    item.batchNumber || '',
                    item.serialNumber || '',
                    item.mfgDate || '',
                    item.expiryDate || '',
                    item.hsn || '',
                    item.taxableValue?.toString() || '0.00',
                    (item.CGSTRate || '0.00') + '%',
                    item.CGSTAmount || '0.00',
                    (item.SGSTRate || '0.00') + '%',
                    item.SGSTAmount || '0.00',
                    (item.IGSTRate || '0.00') + '%',
                    item.IGSTAmount || '0.00',
                    item.totalValue?.toString() || '0.00'
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
                rowData.forEach((data, colIndex) => {
                    // Handle long text by splitting
                    const maxWidth = colWidths[colIndex] - 2;
                    const splitText = doc.splitTextToSize(data.toString(), maxWidth);

                    // Center the text
                    const textY = yPosition + rowHeight / 2;
                    if (splitText.length === 1) {
                        doc.text(splitText[0], xPosition + colWidths[colIndex] / 2, textY, { align: 'center' });
                    } else {
                        // Multiple lines - show first line with ellipsis if needed
                        const displayText = splitText[0].length > maxWidth ? splitText[0].substring(0, maxWidth - 3) + '...' : splitText[0];
                        doc.text(displayText, xPosition + colWidths[colIndex] / 2, textY, { align: 'center' });
                    }

                    // Draw vertical lines
                    if (colIndex > 0) {
                        doc.line(xPosition, yPosition, xPosition, yPosition + rowHeight);
                    }
                    xPosition += colWidths[colIndex];
                });
                yPosition += rowHeight;
            });

            // Total row
            const totalValues = [
                this.totalTaxableValue || '0.00',
                this.totalCGSTAmount || '0.00',
                this.totalSGSTAmount || '0.00',
                this.totalIGSTAmount || '0.00',
                this.totalFinalValue || '0.00'
            ];

            const totalColspan = 11; // How many columns "Total" label spans
            const totalRowHeight = 10; // Same height as data rows

            // Calculate width for first 12 columns (for "Total" label)
            let totalColWidth = 0;
            for (let i = 0; i < totalColspan; i++) {
                totalColWidth += colWidths[i];
            }

            // Draw background and border for the entire row
            doc.setFillColor(240, 240, 240);
            doc.rect(margin, yPosition, printableWidth, totalRowHeight, 'F');
            doc.rect(margin, yPosition, printableWidth, totalRowHeight);

            // Draw the "Total" label in the merged cell
            xPosition = margin;
            doc.setFont('helvetica', 'bold');
            doc.text('Total', xPosition + totalColWidth / 2, yPosition + totalRowHeight / 2, { align: 'center' });

            // Draw vertical line after merged cell
            doc.line(xPosition + totalColWidth, yPosition, xPosition + totalColWidth, yPosition + totalRowHeight);

            // Move xPosition to after colspan
            xPosition += totalColWidth;

            // Start drawing total values
            doc.setFont('helvetica', 'normal');

            // Taxable Value (column 12)
            doc.text(totalValues[0], xPosition + colWidths[11] / 2, yPosition + totalRowHeight / 2, { align: 'center' });
            doc.line(xPosition, yPosition, xPosition, yPosition + totalRowHeight);
            xPosition += colWidths[11];

            // CGST Amount (merge columns 13 and 14: "CGST Rate" and "CGST Amt.")
            let cgstWidth = colWidths[12] + colWidths[13];
            doc.text(totalValues[1], xPosition + cgstWidth / 2, yPosition + totalRowHeight / 2, { align: 'center' });
            doc.line(xPosition, yPosition, xPosition, yPosition + totalRowHeight);
            xPosition += cgstWidth;

            // SGST Amount (merge columns 15 and 16: "SGST Rate" and "SGST Amt.")
            let sgstWidth = colWidths[14] + colWidths[15];
            doc.text(totalValues[2], xPosition + sgstWidth / 2, yPosition + totalRowHeight / 2, { align: 'center' });
            doc.line(xPosition, yPosition, xPosition, yPosition + totalRowHeight);
            xPosition += sgstWidth;

            // IGST Amount (merge columns 17 and 18: "IGST Rate" and "IGST Amt.")
            let igstWidth = colWidths[16] + colWidths[17];
            doc.text(totalValues[3], xPosition + igstWidth / 2, yPosition + totalRowHeight / 2, { align: 'center' });
            doc.line(xPosition, yPosition, xPosition, yPosition + totalRowHeight);
            xPosition += igstWidth;

            // Total Value (column 19)
            doc.text(totalValues[4], xPosition + colWidths[18] / 2, yPosition + totalRowHeight / 2, { align: 'center' });
            doc.line(xPosition, yPosition, xPosition, yPosition + totalRowHeight);

            yPosition += totalRowHeight + 10;
        }

        // Amount in Words
        doc.setFontSize(11);
        doc.setFont('helvetica', 'bold');
        const words = this.amountInWords || 'N/A';
        doc.text(`Amount (In Words) : ${words}`, margin, yPosition + 4);
        yPosition += 15;

        // Footer Section
        if (yPosition > pageHeight - 60) {
            doc.addPage();
            yPosition = 20;
        }

        const footerHeight = 50;
        const footerWidth = pageWidth - margin * 2;
        const footerLeftWidth = footerWidth * 0.75;
        const footerRightWidth = footerWidth * 0.25;

        doc.rect(margin, yPosition, footerWidth, footerHeight);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(9);

        let termsY = yPosition + 4;
        const terms = [
            { text: 'For Reference No. please refer Product Catalogue.', bold: true },
            { text: 'It will be sole responsibility of the Consignee to monitor non use of expired product.', bold: false },
            { text: 'Subject to Ahmedabad Jurisdiction.', bold: true },
            { text: 'Goods once sold are not returnable.', bold: true },
            { text: 'Our risk and responsibility cease once the goods leave our premises.', bold: false },
            { text: 'Claim for any loss in the consignment should be settled by the buyer directly with the carrier.', bold: false },
            { text: 'Declaration :', bold: true },
            { text: 'We declare that this invoice shows that actual price of the goods described and that all particulars are true and correct', bold: false }
        ];

        terms.forEach((term) => {
            doc.setFont('helvetica', term.bold ? 'bold' : 'normal');
            const splitText = doc.splitTextToSize(term.text, footerLeftWidth - 4);
            doc.text(splitText, margin + 2, termsY);
            termsY += splitText.length * 3.5;
        });

        doc.line(margin + footerLeftWidth, yPosition, margin + footerLeftWidth, yPosition + footerHeight);
        const signatureX = margin + footerLeftWidth;
        const signatureWidth = footerRightWidth;
        const signatureHeight = footerHeight / 2;

        doc.setFont('helvetica', 'bold');
        doc.setFontSize(9);
        doc.text('Receiver Signature', signatureX + signatureWidth / 2, yPosition + 8, { align: 'center' });
        doc.line(signatureX, yPosition + signatureHeight, signatureX + signatureWidth, yPosition + signatureHeight);
        doc.text('Authorised Signatory', signatureX + signatureWidth / 2, yPosition + signatureHeight + 8, { align: 'center' });

        const fileName = `Delivery_Challan_${this.deliveryChallanNumber || 'Document'}.pdf`;
        doc.save(fileName);

        this.showToast('Success', 'PDF downloaded successfully!', 'success');

    }
    showToast(title, message, variant) {
        const event = new CustomEvent('showtoast', {
            detail: {
                title: title,
                message: message,
                variant: variant
            }
        });
        this.dispatchEvent(event);
    }

}