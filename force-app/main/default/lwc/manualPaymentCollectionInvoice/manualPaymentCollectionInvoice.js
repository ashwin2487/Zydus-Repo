import { getRecord } from 'lightning/uiRecordApi';
import { LightningElement, track, wire, api } from 'lwc';
import saveInvoicePaymentDetails from '@salesforce/apex/InvoiceCreationController.saveInvoicePaymentDetails';    
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

const FIELDS = [
    'Invoice__c',
    'Invoice__c.Total_Amount__c',
    'Invoice__c.Total_Pending_Amount__c'
];

export default class ManualPaymentCollectionInvoice extends LightningElement {
    @api recordId;
    @track amountToPay = 0;
    @track status = 'Unpaid';
    @track paymentMode = '';
    @track totalAmount;
    @track totalRemainingAmount;
    invoiceDetails;
    @track comment;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.invoiceDetails = data;
            this.setInvoiceDetails();
        } else if (error) {
            console.log('Error fetching invoice record: ', error);
        }
    }

    setInvoiceDetails() {
        const data = this.invoiceDetails?.fields;

        this.totalAmount = data?.Total_Amount__c?.value;
        this.totalRemainingAmount = data?.Total_Pending_Amount__c?.value;
    }

    paymentModeOptions = [
        { label: 'Cash', value: 'Cash' },
        { label: 'Bank Transfer', value: 'Bank Transfer' },
        { label: 'Cheque', value: 'Cheque' },
    ];

    handleAmountChange(event) {
        this.amountToPay = event.detail.value;
    }

    handlePaymentModeChange(event) {
        this.paymentMode = event.detail.value;
    }
    handleCommentChange(event){
        this.comment = event.detail.value;
    }

    handleSubmit() {
        if (this.amountToPay <= 0 || this.amountToPay > this.totalRemainingAmount || !this.paymentMode) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please enter a valid amount and select a payment mode.',
                    variant: 'error'
                })
            );
            return;
        }

        const payload = {
            collectedAmt: this.amountToPay,
            paymentMode: this.paymentMode,
            invoiceId: this.recordId,
            comment: this.comment
        }

        saveInvoicePaymentDetails({ paymentDetails: JSON.stringify(payload) })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Payment recorded successfully.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Error recording payment: ' + error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}