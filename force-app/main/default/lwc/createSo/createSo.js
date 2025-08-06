import { LightningElement, api, wire, track } from 'lwc';
import getOpportunityWithWarehouseData from '@salesforce/apex/OpportunitySupplyOrderHelper.getOpportunityWithWarehouseData';
import createSupplyOrderFromOpportunity from '@salesforce/apex/OpportunitySupplyOrderHelper.createSupplyOrderFromOpportunity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getWPLIBySerialNumber from '@salesforce/apex/OpportunitySupplyOrderHelper.getWPLIBySerialNumber';
import createSOBySerialNumbers from '@salesforce/apex/OpportunitySupplyOrderHelper.createSOBySerialNumbers';
import getSerialNumbers from '@salesforce/apex/OpportunitySupplyOrderHelper.getSerialNumbers';
const SEARCH_DELAY = 350;
const SERIAL_NUMBER_SIZE = 15;
export default class CreateSo extends NavigationMixin(LightningElement) {
    @api recordId;
    @track lineItems = [];
    @track isCreateDisabled = true;
    @track selectedRows = new Set();
    @track isAllSelected = false;
    @track selectedOption;
    isBarcodeScanning = false;
    isFifoBased = false;
    @track createSOLable = 'Create Supply Order';
    @track createSOLableScan = 'Create Supply Order Scan';
    @track isCreateDisabled = true;
    @track isCreateDisabledScan;
    @track bulkSerialInput = '';
    @track isBulkScanEnabled = true;
    isLoading=false;


    @wire(getOpportunityWithWarehouseData, { purchaseOrderId: '$recordId' })
    wiredData({ error, data }) {
        this.isLoading = true;
        if (data) {
            console.log('DATA', data);
            this.lineItems = data.map(item => {
                const mrp = parseFloat(item.mrp || 0);
                const cgst = parseFloat(item.cgst || 0);
                const sgst = parseFloat(item.sgst || 0);
                const igst = parseFloat(item.igst || 0);
                const pendingQty = parseFloat(item.pendingQty || 0);
                const availableQty = parseFloat(item.availableQty || 0);
                const finalQty = availableQty >= pendingQty ? pendingQty : availableQty;
                const baseAmount = mrp * finalQty;
                const cgstAmount = (baseAmount * cgst) / 100;
                const sgstAmount = (baseAmount * sgst) / 100;
                const igstAmount = (baseAmount * igst) / 100;
                const netAmount = baseAmount + cgstAmount + sgstAmount + igstAmount;

                const warehouseOptions = (item.warehouseOptions || []).map(opt => ({
                    label: opt.label,
                    value: opt.value,
                    quantity: opt.quantity
                }));

                let selectedWarehouse = item.SelectedWarehouse || '';
                if (warehouseOptions.length === 1) {
                    selectedWarehouse = warehouseOptions[0].value;
                }

                return {
                    ...item,
                    isSelected: false,
                    SelectedWarehouse: selectedWarehouse,
                    AvailableQty: availableQty,
                    requestedQty: item.requestedQty || 0,
                    pendingQty: pendingQty,
                    finalQty: 0,
                    CGSTAmount: cgstAmount,
                    SGSTAmount: sgstAmount,
                    IGSTAmount: igstAmount,
                    NetAmount: netAmount,
                    showScanBox: true,
                    scannedQty: 0,
                    CGSTAmountFormatted: this.formatINR(cgstAmount),
                    SGSTAmountFormatted: this.formatINR(sgstAmount),
                    IGSTAmountFormatted: this.formatINR(igstAmount),
                    UnitPriceFormatted: this.formatINR(mrp),
                    FinalPriceFormatted: this.formatINR(mrp),
                    NetAmountFormatted: this.formatINR(netAmount),
                    warehouseOptions: warehouseOptions,
                    pricebookEntry: item.pricebookEntry,
                    hsnCode: item.hsnCode,
                    hsnId: item.hsnId,
                    MRPFormatted: this.formatINR(mrp),
                };
            });
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.lineItems = [];
            console.error(error);
        }
    }

    radioOptions = [
        { label: 'FIFO Based', value: 'fifoBased' },
        { label: 'Barcode Scanning', value: 'barcodeScanning' }
    ];

    handleRadioChange(event) {
        this.selectedOption = event.detail.value;

        if (this.selectedOption === 'barcodeScanning') {
            this.isBarcodeScanning = true;
            this.isFifoBased = false;
        }
        if (this.selectedOption === 'fifoBased') {
            this.isFifoBased = true;
            this.isBarcodeScanning = false;
        }
    }

    formatINR(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2
        }).format(value);
    }

    handleSelectAllCheckbox(event) {
        const checked = event.target.checked;
        this.isAllSelected = checked;
        this.lineItems = this.lineItems.map(item => ({ ...item, isSelected: checked }));
        this.selectedRows = checked ? new Set(this.lineItems.map(i => i.lineItemId)) : new Set();
        this.isCreateDisabled = this.selectedRows.size === 0;
    }

    handleCheckboxChange(event) {
        const rowId = event.target.dataset.id;
        const item = this.lineItems.find(i => i.lineItemId === rowId);
        if (item) item.isSelected = event.target.checked;

        this.selectedRows = new Set(this.lineItems.filter(i => i.isSelected).map(i => i.lineItemId));
        this.isCreateDisabled = this.selectedRows.size === 0;
        this.isAllSelected = this.lineItems.length > 0 && this.lineItems.every(i => i.isSelected);
        this.lineItems = [...this.lineItems];
    }

    handleWarehouseChange(event) {
        const rowId = event.target.dataset.id;
        const warehouseId = event.detail.value;
        const item = this.lineItems.find(i => i.lineItemId === rowId);

        if (item) {
            item.SelectedWarehouse = warehouseId;
            const selected = item.warehouseOptions.find(opt => opt.value === warehouseId);
            item.AvailableQty = selected ? selected.quantity : 0;

            const mrp = parseFloat(item.mrp || 0);
            const cgstRate = parseFloat(item.cgst || 0);
            const sgstRate = parseFloat(item.sgst || 0);
            const igstRate = parseFloat(item.igst || 0);

            const pendingQty = parseFloat(item.pendingQty || 0);
            const availableQty = parseFloat(item.AvailableQty || 0);

            if (availableQty > 0 && pendingQty > 0) {
                const finalQty = availableQty >= pendingQty ? pendingQty : availableQty;

                const baseAmount = mrp * finalQty;
                const cgstAmount = (baseAmount * cgstRate) / 100;
                const sgstAmount = (baseAmount * sgstRate) / 100;
                const igstAmount = (baseAmount * igstRate) / 100;
                const netAmount = baseAmount + cgstAmount + sgstAmount + igstAmount;

                item.finalQty = finalQty;
                item.CGSTAmount = cgstAmount;
                item.SGSTAmount = sgstAmount;
                item.IGSTAmount = igstAmount;
                item.NetAmount = netAmount;

                item.CGSTAmountFormatted = this.formatINR(cgstAmount);
                item.SGSTAmountFormatted = this.formatINR(sgstAmount);
                item.IGSTAmountFormatted = this.formatINR(igstAmount);
                item.NetAmountFormatted = this.formatINR(netAmount);
            } else {
                item.finalQty = 0;
                item.CGSTAmount = 0;
                item.SGSTAmount = 0;
                item.IGSTAmount = 0;
                item.NetAmount = 0;

                item.CGSTAmountFormatted = this.formatINR(0);
                item.SGSTAmountFormatted = this.formatINR(0);
                item.IGSTAmountFormatted = this.formatINR(0);
                item.NetAmountFormatted = this.formatINR(0);
            }

            this.lineItems = [...this.lineItems];
        }
    }

    handleCreateSO() {
        const payload = [];

        for (const id of this.selectedRows) {
            const item = this.lineItems.find(i => i.lineItemId === id);
            if (!item) continue;

            if (!item.SelectedWarehouse) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Missing Warehouse',
                    message: `Please select a warehouse for ${item.productName}.`,
                    variant: 'error'
                }));
                return;
            }

            const requestedQty = parseFloat(item.requestedQty || 0);
            const pendingQty = parseFloat(item.pendingQty || 0);
            const availableQty = parseFloat(item.AvailableQty || 0);

            if (requestedQty < pendingQty) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Quantity Error',
                    message: `Pending quantity for ${item.productName} exceeds requested quantity.`,
                    variant: 'error'
                }));
                return;
            }

            if (availableQty <= 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Insufficient Stock',
                    message: `Available quantity is zero for ${item.productName}.`,
                    variant: 'error'
                }));
                return;
            }

            const finalQty = availableQty >= pendingQty ? pendingQty : availableQty;

            if (finalQty <= 0) {
                continue;
            }

            const mrp = parseFloat(item.mrp || 0); // ✅ MRP instead of unitPrice
            const baseAmount = mrp;
            const cgstAmount = (baseAmount * parseFloat(item.cgst || 0)) / 100;
            const sgstAmount = (baseAmount * parseFloat(item.sgst || 0)) / 100;
            const igstAmount = (baseAmount * parseFloat(item.igst || 0)) / 100;
            const netAmount = baseAmount + cgstAmount + sgstAmount + igstAmount;

            payload.push({
                lineItemId: id,
                productId: item.productId,
                quantity: finalQty,
                mrp: mrp,
                cgst: cgstAmount,
                sgst: sgstAmount,
                igst: igstAmount,
                netAmount: netAmount,
                warehouseId: item.SelectedWarehouse,
                hsnId: item.hsnId,
                availableQty: availableQty,
                pricebookEntry: item.pricebookEntry
            });
        }

        console.log('payload', JSON.stringify(payload));
        if (!payload.length) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No Valid Items',
                message: 'No valid line items to create a Supply Order.',
                variant: 'warning'
            }));
            return;
        }

        this.createSOLable = 'Creating Supply Order... ';
        this.isCreateDisabled = true;

        createSupplyOrderFromOpportunity({
            purchaseOrderId: this.recordId,
            linesJson: JSON.stringify(payload)
        })
            .then((SoId) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Supply Order created successfully!',
                    variant: 'success'
                }));

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: SoId,
                        objectApiName: 'Supply_Order__c',
                        actionName: 'view'
                    }
                });
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || error.message || 'Unknown error occurred',
                    variant: 'error'
                }));
            });
    }

    /**
     * SCANNING BARNCODE SCANNING BARNCODE SCANNING BARNCODE SCANNING BARNCODE SCANNING BARNCODE SCANNING BARNCODE SCANNING BARNCODE SCANNING BARNCODE SCAN
     */
    @track scannedList = [];
    @track scannedSerialNumber = '';

    get isListEmpty() {
        return this.scannedList.length === 0;
    }

    get hasScannedItems() {
        return this.scannedList.length > 0;
    }
    get scannedByProduct() {
        if (!this.scannedList || this.scannedList.length === 0) {
            return [];
        }

        // Group scanned items by Product ID
        const grouped = this.scannedList.reduce((acc, item) => {
            const productId = item.productId; // Group by the product ID field from the scanned record

            if (!acc[productId]) {
                acc[productId] = {
                    Id: productId,
                    productName: item.productName, // Use the name we added
                    items: [],
                    count: 0,
                    pendingQty: item.pendingQty
                };
            }

            acc[productId].items.push(item);
            acc[productId].count++;

            // const updatedLineItems = this.lineItems.map(item => {
            //     if (item.productId === productId) {
            //         return {
            //             ...item,
            //             scannedQty: acc[productId].count || 0
            //         };
            //     }
            //     return item;
            // });

            // this.lineItems = updatedLineItems;
            return acc;
        }, {});

        return Object.values(grouped);
    }
    get bulkScanPlaceholder() {
        return `Scan ${SERIAL_NUMBER_SIZE} Character Serial Number Here...`
    }

    handleRemoveSerial(event) {
        const serialId = event.target.dataset.id;
        this.scannedList = this.scannedList.filter(item => item.Id !== serialId);
        this.updateLineItemScannedQuantities();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    handleSelectAllCheckboxScan(event) {
        const isChecked = event.target.checked;
        this.isAllSelectedScan = isChecked;
        this.lineItems = this.lineItems.map(item => ({ ...item, isSelectedScan: isChecked, showScanBox: isChecked == true ? false : true }));
    }

    handleCheckboxChangeScan(event) {
        const lineItemId = event.target.dataset.lineitemid;
        const isChecked = event.target.checked;
        const updatedLineItems = this.lineItems.map(item => {
            if (item.lineItemId === lineItemId) {
                return {
                    ...item,
                    isSelectedScan: isChecked,
                    showScanBox: !isChecked
                };
            }
            return item;
        });

        setTimeout(() => {
            const inputCmp = this.template.querySelector('[data-id="inputField"]');
            if (inputCmp) {
                inputCmp.focus();
            }
        }, 0);

        this.lineItems = updatedLineItems;
        this.isAllSelectedScan = updatedLineItems.length > 0 && updatedLineItems.every(item => item.isSelectedScan);
    }
    get isCreateSOBtnDisabledScan() {
        return this.isCreateDisabledScan || this.scannedList.length === 0;
    }

    handleCreateSOScan() {
        const lineItemMap = new Map(this.lineItems.map(line => [line.productId, line]));

        const soLinesBySerial = this.scannedList.map(scannedItem => {

            const originalLine = lineItemMap.get(scannedItem.productId);

            if (!originalLine) {
                console.error('Could not find matching line item for scanned product:', scannedItem.productId);
                return null;
            }
            const mrp = originalLine.mrp;
            const cgstValue = mrp * (originalLine.cgst / 100);
            const sgstValue = mrp * (originalLine.sgst / 100);
            const igstValue = mrp * (originalLine.igst / 100);
            const netAmountValue = mrp + cgstValue + sgstValue + igstValue;

            return {
                lineItemId: originalLine.lineItemId,
                productId: scannedItem.productId,
                serialNumber: scannedItem.Serial_Number__c,
                mrp: mrp,
                cgst: cgstValue,
                sgst: sgstValue,
                igst: igstValue,
                netAmount: netAmountValue,
                warehouseId: scannedItem.Connected_Warehouse__c,
                hsnId: originalLine.hsnId,
                pricebookEntry: originalLine.pricebookEntry
            };
        }).filter(line => line !== null);

        this.createSOLableScan = 'Creating Supply Order...';
        this.isCreateDisabledScan = true;

        createSOBySerialNumbers({ purchaseOrderId: this.recordId, linesJson: JSON.stringify(soLinesBySerial) })
            .then(SoId => {
                this.showToast('SO Created', 'Supply Order Created Successfully', 'success');

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: SoId,
                        objectApiName: 'Supply_Order__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.showToast('Error', error.message, 'error');
            });
    }
    handleBulkScanToggle(event) {
        this.isBulkScanEnabled = event.target.checked;
        setTimeout(() => {
            const inputEl = this.template.querySelector('[data-id="inputFieldScan"]');
            if (inputEl) {
                inputEl.focus();
            } else {
                console.warn('Input element not found');
            }
        }, 0);
    }

    handleBulkSerialChange(event) {
        this.bulkSerialInput = event.target.value;
        const serialNumber = event.target.value;
        const productIds = this.lineItems.map(item => item.productId);

        if (serialNumber && serialNumber.length === SERIAL_NUMBER_SIZE) {
            //this.isLoading = true;
            getWPLIBySerialNumber({ serialNumber: serialNumber, productId: productIds })
                .then(result => {
                    if (result) {
                        const productId = result.Warehouse__r.Zydus_Product__c;
                        const productName = result.Warehouse__r.Zydus_Product__r.Name;
                        const targetLineItem = this.lineItems.find(item => item.productId === productId);
                        const PendingQty = targetLineItem ? targetLineItem.pendingQty : 0;
                        console.log('productId', productId);
                        const count = this.scannedList.filter(item => item.productId === productId).length;
                        if (parseInt(PendingQty, 10) === count) {
                            this.showToast('Maximum Quantity Reached', `Scanning complete - all items have been scanned for ${productName}`, 'warning');
                            this.bulkSerialInput = '';
                            return;
                        }

                        const isDuplicate = this.scannedList.some(item => item.Serial_Number__c === serialNumber);
                        if (isDuplicate) {
                            this.showToast('Duplicate', `Serial "${serialNumber}" has already been scanned.`, 'warning');
                            this.bulkSerialInput = '';
                            return;
                        }

                        let newRecord = { ...result };
                        newRecord.warehouse = result.Connected_Warehouse__r.Name;
                        newRecord.productName = result.Warehouse__r.Zydus_Product__r.Name;
                        newRecord.pendingQty = PendingQty;
                        newRecord.productId = productId;
                        this.scannedList = [...this.scannedList, newRecord];
                        this.updateLineItemScannedQuantities();
                        this.bulkSerialInput = '';
                        this.showToast('Success', `Serial "${serialNumber}" has been scanned.`, 'success');
                    } else {
                        this.showToast('Not Found', `Serial "${serialNumber}" is not valid or not found.`, 'error');
                    }
                })
                .catch(error => {
                    this.showToast('Error', error.body?.message || error.message, 'error');
                })
                .finally(() => {
                    this.scannedSerialNumber = '';
                    this.isLoading = false;
                });
        }
    }
    updateLineItemScannedQuantities() {
        const scannedCounts = {};
        this.scannedList.forEach(item => {
            scannedCounts[item.productId] = (scannedCounts[item.productId] || 0) + 1;
        });

        const updatedLineItems = this.lineItems.map(item => {
            return {
                ...item,
                scannedQty: scannedCounts[item.productId] || 0
            };
        });

        this.lineItems = updatedLineItems;
    }
    @track SerialNumbersToDisplay = [];

    handleBlur() {
        setTimeout(() => {
            this.lineItems = this.lineItems.map(item => {
                return { ...item, isActive: false };
            });
        }, 200);
    }

    handleFocus(event) {
        const serialNumber = '';
        const productId = event.target.dataset.productid;
        this.setActiveRow(productId);
        this.fetchSerialNumber(serialNumber, productId);
    }

    handleInput(event) {
        this.scannedSerialNumber = event.target.value;
        const serialNumber = event.target.value;
        const productId = event.target.dataset.productid;
        console.log('serial Number: ', serialNumber);
        console.log('productId: ', productId);
        this.setActiveRow(productId);
        this.fetchSerialNumber(serialNumber, productId);
    }

    async fetchSerialNumber(serialNumber, productId) {
        console.log('INSIDE FETCH SERIAL NUMBER');
        await getSerialNumbers({ keyword: serialNumber, productId: productId })
            .then((result) => {
                this.SerialNumbersToDisplay = result.map(serial => serial.Serial_Number__c);
                this.showResults = true;
            }).catch((error) => {
                console.log('error:', error);
            })
    }
    setActiveRow(pId) {
        this.lineItems = this.lineItems.map(item => {
            return { ...item, isActive: item.productId === pId };
        });
        console.log('LINEITEM:', this.lineItems);
    }

    handleSNClick(event) {
        const dataset = event.currentTarget.dataset;
        const serial = dataset.id;
        const productId = dataset.productid;
        const productName = dataset.productname;
        const PendingQty = dataset.pendingqty;
        
        if (!serial) return;

        const count = this.scannedList.filter(item => item.productId === productId).length;
        if (parseInt(PendingQty, 10) === count) {
            this.showToast('Maximum Quantity Reached', `Scanning complete - all items have been scanned for ${productName}`, 'warning');
            this.scannedSerialNumber = '';
            return;
        }

        const isDuplicate = this.scannedList.some(item => item.Serial_Number__c === serial);
        if (isDuplicate) {
            this.showToast('Duplicate', `Serial "${serial}" has already been scanned.`, 'warning');
            this.scannedSerialNumber = '';
            return;
        }

        this.isLoading = true;
        getWPLIBySerialNumber({ serialNumber: serial, productId: [productId] })
            .then(result => {
                console.log('getWPLIBySerialNumber:',result);
                if (result) {
                    let newRecord = { ...result };
                    newRecord.warehouse = result.Connected_Warehouse__r.Name;
                    newRecord.productName = productName;
                    newRecord.pendingQty = PendingQty;
                    newRecord.productId = productId;
                    this.scannedList = [...this.scannedList, newRecord];
                    this.updateLineItemScannedQuantities();
                    this.showToast('Success', `Serial "${serial}" has been scanned.`, 'success');
                } else {
                    this.showToast('Not Found', `Serial "${serial}" is not valid or not found.`, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            })
            .finally(() => {
                this.scannedSerialNumber = '';
                this.isLoading = false;
            });
    }
}