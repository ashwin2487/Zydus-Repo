import { LightningElement, api } from 'lwc';
import approvePurchaseOrder from '@salesforce/apex/PurchaseOrderController.approvePurchaseOrder';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class ApprovePurchaseOrder extends LightningElement {
    @api recordId;

    async handleApprove() {
        try {
            await approvePurchaseOrder({ recordId: this.recordId });
            this.showToast('Success', 'Purchase Order approved successfully.', 'success');
            this.closeAction();
        } catch (error) {
            console.error('Error approving Purchase Order:', error);
            this.showToast('Error', error.body?.message || 'An unexpected error occurred.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}