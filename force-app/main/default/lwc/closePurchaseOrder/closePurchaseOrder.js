import { LightningElement, api , track} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import manualPOClosure from '@salesforce/apex/PurchaseOrderController.manualPOClosure';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class ClosePurchaseOrder extends LightningElement {
        @api recordId;
        @track reason = '';
        handleReasonChange(event){
            this.reason = event.target.value;
        }
        async handleClosePO() {
            try {
                await manualPOClosure({ recordId: this.recordId , reason: this.reason});
                this.showToast('Success', 'Purchase Order closed successfully.', 'success');
                this.closeAction();
            } catch (error) {
                console.error('Error closing Purchase Order:', error);
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