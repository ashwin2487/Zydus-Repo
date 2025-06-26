import { LightningElement, api, wire, track } from 'lwc';
import getOpportunityWithWarehouseData from '@salesforce/apex/OpportunitySupplyOrderHelper.getOpportunityWithWarehouseData';
import createSupplyOrderFromOpportunity from '@salesforce/apex/OpportunitySupplyOrderHelper.createSupplyOrderFromOpportunity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CreateSo extends LightningElement {
    @api recordId;
    @track lineItems = [];
    @track isCreateDisabled = true;
    @track selectedRows = new Set();

    @wire(getOpportunityWithWarehouseData, { purchaseOrderId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.lineItems = data.map(item => {
                const unitPrice = parseFloat(item.unitPrice || 0);
                const cgst = parseFloat(item.cgst || 0);
                const sgst = parseFloat(item.sgst || 0);
                const igst = parseFloat(item.igst || 0);
                const pendingQty = parseFloat(item.pendingQty || 0);
                const availableQty = parseFloat(item.availableQty || 0);
                const finalQty = availableQty >= pendingQty ? pendingQty : availableQty;
                const baseAmount = unitPrice * finalQty;
                const cgstAmount = (baseAmount * cgst) / 100;
                const sgstAmount = (baseAmount * sgst) / 100;
                const igstAmount = (baseAmount * igst) / 100;
                const netAmount = baseAmount + cgstAmount + sgstAmount + igstAmount;
                
                return {
                    ...item,
                    isSelected: false,
                    SelectedWarehouse: item.SelectedWarehouse || '',
                    AvailableQty: item.availableQty || 0,
                    requestedQty: item.requestedQty || 0,
                    pendingQty: item.pendingQty || 0,
                    finalQty: 0,
                    CGSTAmount: cgstAmount,
                    SGSTAmount: sgstAmount,
                    IGSTAmount: igstAmount,
                    NetAmount: netAmount,
                    CGSTAmountFormatted: this.formatINR(cgstAmount),
                    SGSTAmountFormatted: this.formatINR(sgstAmount),
                    IGSTAmountFormatted: this.formatINR(igstAmount),
                    UnitPriceFormatted: this.formatINR(unitPrice),
                    FinalPriceFormatted: this.formatINR(unitPrice),
                    NetAmountFormatted: this.formatINR(netAmount),
                    warehouseOptions: (item.warehouseOptions || []).map(opt => ({
                        label: opt.label,
                        value: opt.value,
                        quantity: opt.quantity
                    })),
                    pricebookEntry: item.pricebookEntry,
                    hsnCode: item.hsnCode,
                    hsnId: item.hsnId
                };
            });
        } else if (error) {
            this.lineItems = [];
            console.error(error);
        }
    }

    formatINR(value) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2
        }).format(value);
    }

    handleCheckboxChange(event) {
        const rowId = event.target.dataset.id;
        const item = this.lineItems.find(i => i.lineItemId === rowId);
        if (item) item.isSelected = event.target.checked;

        this.selectedRows = new Set(this.lineItems.filter(i => i.isSelected).map(i => i.lineItemId));
        this.isCreateDisabled = this.selectedRows.size === 0;
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

        const unitPrice = parseFloat(item.unitPrice || 0);
        const cgstRate = parseFloat(item.cgst || 0);
        const sgstRate = parseFloat(item.sgst || 0);
        const igstRate = parseFloat(item.igst || 0);

        const pendingQty = parseFloat(item.pendingQty || 0);
        const availableQty = parseFloat(item.AvailableQty || 0);

        if (availableQty > 0 && pendingQty > 0) {
            const finalQty = availableQty >= pendingQty ? pendingQty : availableQty;

            const baseAmount = unitPrice * finalQty;
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
                    message: `pending  quantity for ${item.productName} exceeds Requested quantity.`,
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
            const unitPrice = parseFloat(item.unitPrice || 0);
            const baseAmount = unitPrice;
            const cgstAmount = (baseAmount * parseFloat(item.cgst || 0)) / (100);
            const sgstAmount = (baseAmount * parseFloat(item.sgst || 0)) / (100);
            const igstAmount = (baseAmount * parseFloat(item.igst || 0)) / (100);
            const netAmount = baseAmount + cgstAmount + sgstAmount + igstAmount;

            payload.push({
                lineItemId: id,
                productId: item.productId,
                quantity: finalQty,
                unitPrice: unitPrice,
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

        createSupplyOrderFromOpportunity({
            purchaseOrderId: this.recordId,
            linesJson: JSON.stringify(payload)
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Supply Order created successfully!',
                    variant: 'success'
                }));
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
}