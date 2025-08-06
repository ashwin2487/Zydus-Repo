import { LightningElement, api, track, wire } from 'lwc';
import getDeliveryChallanDetails from '@salesforce/apex/GRNController.getDeliveryChallanDetails';
import processGRN from '@salesforce/apex/GRNController.processGRN';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
const SERIAL_NUMBER_LENGTH = 15;
export default class GenerateGRNByScan extends NavigationMixin(LightningElement) {

    @api recordId;
    @track dcName;
    @track warehouseOptions = [];
    @track error;

    @track status = 'Accepted';
    @track rejectionReason = '';
    @track rejectionComment = '';
    @track warehouse = '';

    @track isScanning = false;
    @track scannedItems = [];
    @track lineItems = [];
    @track showProcessGRNBtn;
    @track grnLable = 'Process GRN';

    rejectionReasonOptions = [
        { label: 'Damaged', value: 'Damaged' },
        { label: 'Wrong Item', value: 'Wrong Item' },
        { label: 'Expired', value: 'Expired' },
        { label: 'Others', value: 'Others' }
    ];

    @wire(getDeliveryChallanDetails, { challanId: '$recordId' })
    wiredChallan({ data, error }) {
        if (data) {
            console.log('data', data);
            this.dcName = data.dcName;
            this.lineItems = data.lineItems;
            this.warehouseOptions = data.warehouseOptions;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || error.message;
            this.dcName = undefined;
            this.warehouseOptions = [];
        }
    }

    handleStatusChange(event) {
        this.warehouse = '';
        this.status = event.target.dataset.status;
        if (this.status === 'Accepted') {
            this.rejectionReason = '';
            this.rejectionComment = '';
        }
    }

    handleReasonChange(event) {
        this.rejectionReason = event.detail.value;
        const inputEl = this.template.querySelector('[data-id="inputField"]');
        if (inputEl) {
            inputEl.focus();
        }
    }

    handleChangeRejectionCommentChange(event) {
        this.rejectionComment = event.detail.value;
    }

    handleWarehouseChange(event) {
        this.warehouse = event.detail.value;
        setTimeout(() => {
            const inputEl = this.template.querySelector('[data-id="inputField"]');
            if (inputEl) {
                inputEl.focus();
            } else {
                console.warn('Input element not found');
            }
        }, 0);
    }


    get bulkScanPlaceholder() {
        return `Scan ${SERIAL_NUMBER_LENGTH} Character Serial Number Here...`
    }
    get isRejectStatus() {
        return this.status === 'Rejected';
    }

    get hasScannedItems() {
        return this.scannedItems.length > 0;
    }
    get showProcessGRNBtnGetter() {
        return this.showProcessGRNBtn || this.scannedItems.length === 0;
    }

    get warehouseLabel() {
        return this.isRejectStatus ? this.rejectionReason === 'Others' ? '4. Warehouse' : '3. Warehouse' : '2. Warehouse';
    }

    get showWarehouse() {
        return this.isRejectStatus && this.rejectionReason === '';
    }

    get isScanDisabled() {
        return !this.warehouse;
    }

    get acceptButtonClass() {
        return this.status === 'Accepted' ? 'slds-button slds-button_brand' : 'slds-button slds-button_neutral';
    }

    get rejectButtonClass() {
        return this.status === 'Rejected' ? 'slds-button slds-button_destructive' : 'slds-button slds-button_neutral';
    }

    get rejectionReasonClass() {
        return this.isRejectStatus ? 'slds-show' : 'slds-hide';
    }

    get showRejectionCommentClass() {
        return this.isRejectStatus && this.rejectionReason === 'Others' ? 'slds-show' : 'slds-hide';
    }

    get isRejectionCommentRequired() {
        return this.isRejectStatus && this.rejectionReason === 'Others';
    }

    handleScan(event) {
        if (event.target.value && event.target.value.length === SERIAL_NUMBER_LENGTH) {
            const serial = event.target.value.trim();
            event.target.value = '';
            this.isScanning = true;

            setTimeout(() => {
                if (this.scannedItems.some(item => item.serialNumber === serial)) {
                    this.showToast('Duplicate Scan', `Serial number ${serial} has already been scanned.`, 'warning');
                    return;
                } else {
                    const mockProduct = this.lineItems.find(item => item.serialNumber === serial);
                    if (!mockProduct) {
                        this.showToast('Invalid Scan', `Serial number ${serial} is not found.`, 'warning');
                        return;
                    }
                    const selectedWarehouse = this.warehouseOptions.find(w => w.value === this.warehouse);

                    let reason = '';
                    if (this.isRejectStatus) {
                        reason = this.rejectionReason === 'Others' ? this.rejectionComment.substring(0, 20) + '...' : this.rejectionReason;
                    }

                    const newItem = {
                        ...mockProduct,
                        status: this.status,
                        selectedWarehouseId: this.warehouse,
                        warehouse: selectedWarehouse ? selectedWarehouse.label : '',
                        reason: reason,
                        rejectionReason: this.rejectionReason,
                        rejectionComment: this.rejectionComment,
                        iconName: this.isRejectStatus ? 'utility:close' : 'utility:success',
                        iconVariant: this.isRejectStatus ? 'error' : 'success',
                    };
                    this.scannedItems = [newItem, ...this.scannedItems];
                }
                this.isScanning = false;
            }, 300);
        }
    }

    handleRemoveItem(event) {
        const serialToRemove = event.target.dataset.serial;
        this.scannedItems = this.scannedItems.filter(item => item.serialNumber !== serialToRemove);
        this.showToast('Item Removed', `Serial number ${serialToRemove} has been removed.`, 'info');
    }

    handleSubmit() {
        console.log('lineItems', this.lineItems);
        console.log('scannedItems', this.scannedItems);

        if (this.scannedItems.length < this.lineItems.length) {
            this.showToast('Validation Error', `Please scan all (${this.scannedItems.length} / ${this.lineItems.length}) line items before submitting.`, 'error');
            return;
        }
        const invalidItems = this.scannedItems.filter(item => !item.status);
        const noWarehouseSelected = this.scannedItems.filter(item => !item.selectedWarehouseId);

        if (invalidItems.length > 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please select status for all line items before submitting.',
                    variant: 'error'
                })
            );
            return;
        }

        if (noWarehouseSelected.length > 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please assign a warehouse to all line items before submitting.',
                    variant: 'error'
                })
            );
            return;
        }
        this.showProcessGRNBtn = true;
        this.grnLable = 'Processing...';

        processGRN({
            challanId: this.recordId,
            lineItems: this.scannedItems
        })
            .then((grnId) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'GRN processed successfully.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: grnId,
                        objectApiName: 'Warehouse__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.error = error.body?.message || error.message;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: this.error,
                        variant: 'error'
                    })
                );
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}