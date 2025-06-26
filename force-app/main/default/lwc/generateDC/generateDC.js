import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createDeliveryChallan from '@salesforce/apex/GenerateDeliveryChallan.createDeliveryChallan';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class GenerateDC extends LightningElement {
    @api recordId;

    createDC() {
        createDeliveryChallan({ supplyOrderId: this.recordId })
            .then((result) => {
                const unauthorizedMessage = 'Access denied: Unauthorized entry attempt detected. Please reach out to your system administrator immediately.';
                const isAlreadyCreated = result === 'The Delivery Challan for this Supply Order has already been generated!';

                if (result === unauthorizedMessage) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Unauthorized',
                            message: unauthorizedMessage,
                            variant: 'error'
                        })
                    );
                    this.closeCreateDCModal();
                    return;
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: isAlreadyCreated ? 'Alert' : 'Success',
                        message: result,
                        variant: isAlreadyCreated ? 'warning' : 'success'
                    })
                );
            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body?.message || error?.message || 'An unexpected error occurred',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.closeCreateDCModal();
            });
    }

    closeCreateDCModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}