import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createDeliveryChallan from '@salesforce/apex/GenerateDeliveryChallan.createDeliveryChallan';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

export default class GenerateDC extends NavigationMixin(LightningElement) {
    @api recordId;
    disableCreateDCBtn = false;
    @track DCLable = 'Generate Delivery Challan';
    @track courierName;
    @track courierDocket;
    @track courierDate;

    minDate = new Date().toISOString().slice(0, 10);
    handleCourierNameChange(event) {
        this.courierName = event.target.value;
    }
    handleCourierDocketChange(event) {
        this.courierDocket = event.target.value;
    }

    handleCourierDateChange(event) {
        this.courierDate = event.target.value;
    }

    createDC() {

        const allValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((valid, field) => {
                field.reportValidity();
                return valid && field.checkValidity();
            }, true);

        if (!allValid) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please fill all required fields correctly.',
                    variant: 'error'
                })
            );
            return;
        }

        this.DCLable = 'Generating Delivery Challan...';
        this.disableCreateDCBtn = true;
        createDeliveryChallan({ supplyOrderId: this.recordId, courierName: this.courierName, courierDocketNo: this.courierDocket, courierDate:this.courierDate })
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
                        message: isAlreadyCreated? result : 'Delivery Challan created successfully!',
                        variant: isAlreadyCreated ? 'warning' : 'success'
                    })
                );

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: 'Delivery_Challan__c',
                        actionName: 'view'
                    }
                });

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
                this.disableCreateDCBtn = false;
                this.closeCreateDCModal();
            });
    }

    closeCreateDCModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}