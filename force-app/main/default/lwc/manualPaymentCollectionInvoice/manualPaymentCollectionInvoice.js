import { getRecord } from 'lightning/uiRecordApi';
import { LightningElement, track, wire, api } from 'lwc';
import saveInvoicePaymentDetails from '@salesforce/apex/InvoiceCreationController.saveInvoicePaymentDetails';
import saveInvoicePaymentWithCreditNote from '@salesforce/apex/CollectionCreationClass.saveInvoicePaymentWithCreditNote';
import getCreditNoteList from '@salesforce/apex/CollectionCreationClass.getCreditNoteList';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

const FIELDS = [
    'Invoice__c',
    'Invoice__c.Total_Amount__c',
    'Invoice__c.Total_Pending_Amount__c', 'Invoice__c.Hospital__c', 'Invoice__c.Total_Collected_Amount__c', 'Invoice__c.Consignee_Dealer__c'
];

export default class ManualPaymentCollectionInvoice extends LightningElement {
    @api recordId;
    @track amountToPay = 0;
    @track status = 'Unpaid';
    @track paymentMode = '';
    @track totalAmount;
    @track totalRemainingAmount;
    @track totalCollectedAmount;
    invoiceDetails;
    @track comment;

    cnColumns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Total Amount', fieldName: 'Amount__c' },
        {
            label: 'Consumed Amount', fieldName: 'Consumed_Amount__c',
            type: 'editableConsumedAmount',
            typeAttributes: {
                value: { fieldName: 'Consumed_Amount__c' },
                editable: { fieldName: 'isEditable' },
                rowId: { fieldName: 'Id' }
            }
        },
        { label: 'Available Amount', fieldName: 'Available_Amount__c' },
        // no need to define checkbox column explicitly
    ];

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
        this.totalCollectedAmount = data?.Total_Collected_Amount__c?.value;
        this.fetchCreditNotes();
    }
    creditNoteData = [];
    originalRowDataMap = [];
    fetchCreditNotes() {
        const data = this.invoiceDetails?.fields;
        const hospitalId = data?.Hospital__c?.value;
        const accountId = data?.Account__c?.value;
        const recordId = hospitalId || accountId;

        // Set flag based on whether Hospital__c is present
        const isHospital = !!hospitalId;
        getCreditNoteList({ recordId: recordId, isHospital: isHospital })
            .then(result => {
                console.log('Fetch Credit Note Result: ', result);
                this.creditNoteData = result;
                this.originalRowDataMap = result;
            })
            .catch(error => {
                console.error('Fetch Credit Note Error:', error);

            });

    }
    @track totalCreditAmount;

    get calTotalRemainingAmount() {
        return this.totalRemainingAmount - this.amountToPay;
    }

    selectedRowIds = [];
    @api typeAttributes;
    handleRowSelection(event) {
      
        const selectedRows = event.detail.selectedRows;

        let remainingToConsume = this.calTotalRemainingAmount; // 83,800

        const updatedRows = [];
        const selectedRowKeys = []; // To track only those rows that are allowed

        if (!this.originalRowDataMap) {
            this.originalRowDataMap = new Map();
        }

        console.log('originalRowDataMap :', JSON.stringify(this.originalRowDataMap));

        const currentSelectedIds = new Set(selectedRows.map(row => row.Id));
        const previouslySelectedIds = new Set(this.selectedRowIds || []);

        const deselectedIds = [...previouslySelectedIds].filter(id => !currentSelectedIds.has(id));
        console.log('deselectedIds :', JSON.stringify(deselectedIds));

        this.creditNoteData = this.creditNoteData.map(row => {
            if (deselectedIds.includes(row.Id)) {
                console.log('Yes :', row.Id);
                const original = this.originalRowDataMap.find(r => r.Id === row.Id);
                console.log('original :', original);
                if (original) {
                    return {
                        ...row,
                        Available_Amount__c: original.Available_Amount__c,
                        Consumed_Amount__c: original.Consumed_Amount__c
                    };
                }
            }
            return row;
        });


        if (remainingToConsume === 0 && deselectedIds.length === 0) {
            const previousSelectedIds = new Set(this.selectedRowIds || []);
            const currentSelectedIds = new Set(selectedRows.map(row => row.Id));

            const newlySelectedRows = selectedRows.filter(row => !previousSelectedIds.has(row.Id));

            console.log('Newly selected rows:', newlySelectedRows.map(r => r.Id));

            const datatable = this.template.querySelector('lightning-datatable');
            if (datatable) {
                datatable.selectedRows = this.selectedRowIds;
            }


            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'One or more rows have Consumed Amount greater than Available Amount.',
                    variant: 'error'
                })
            );
            return;
        }


        for (let row of selectedRows) {

            console.log('Rows :', JSON.stringify(row));
            const available = parseFloat(row.Available_Amount__c) || 0;
            if (available === 0) {
                updatedRows.push({ ...row });
                selectedRowKeys.push(row.Id);
                continue;
            }

            let consumed = 0;

            if (remainingToConsume > 0) {
                consumed = Math.min(available, remainingToConsume);
                remainingToConsume -= consumed;


            }

            updatedRows.push({
                ...row,
                Consumed_Amount__c: consumed,
                Available_Amount__c: row.Available_Amount__c - consumed
            });
            selectedRowKeys.push(row.Id);
        }
        this.selectedRowIds = selectedRowKeys;
        console.log('Updated Rows :', JSON.stringify(updatedRows));


        // Set in component

        this.amountToPay = updatedRows.reduce((sum, row) => sum + row.Consumed_Amount__c, 0);

        this.creditNoteData = this.creditNoteData.map(row => {
            const updated = updatedRows.find(r => r.Id === row.Id);
            return updated ? { ...row, Consumed_Amount__c: updated.Consumed_Amount__c, Available_Amount__c: updated.Available_Amount__c } : { ...row, Consumed_Amount__c: 0 };
        });

    }

    paymentModeOptions = [
        { label: 'Cash', value: 'Cash' },
        { label: 'Bank Transfer', value: 'Bank Transfer' },
        { label: 'Cheque', value: 'Cheque' },
        { label: 'Credit Note', value: 'Credit Note' },
    ];

    handleAmountChange(event) {
        this.amountToPay = event.detail.value;
    }

    handlePaymentModeChange(event) {
        this.paymentMode = event.detail.value;
    }
    handleCommentChange(event) {
        this.comment = event.detail.value;
    }
    get isCreditNotePaymentMode() {
        return this.paymentMode == 'Credit Note' ? true : false;
    }
    isSaveClick = false;
    get isPaymentSave() {
        if (this.isSaveClick) {
            return true;
        }

        if (this.paymentMode === 'Credit Note' && this.selectedRowIds.length > 0) {
            return false;
        } else if (this.paymentMode != '' && this.paymentMode !== 'Credit Note' && this.amountToPay > 0) {
            return false;
        } else {
            return true;
        }
    }

    handleSubmitWithCreditNote() {

        console.log('handleSubmitWithCreditNote 1');
        if (this.amountToPay <= 0 && this.selectedRowIds.length <= 0) {
            this.toastNotification('Error', 'Please select credit note for this payment mode.');

            return;
        }
        console.log('handleSubmitWithCreditNote 2');
        const invoiceFields = {};
        invoiceFields['Id'] = this.recordId;
        let totalCollectedAmount = Number(this.totalCollectedAmount) +Number(this.amountToPay);
        invoiceFields['Total_Collected_Amount__c'] = totalCollectedAmount ;
        invoiceFields['Payment_Status__c'] = totalCollectedAmount === Number(this.totalAmount) ? 'Fully Paid' : 'Partially Paid';
        invoiceFields['Invoice_Closed__c'] = true;
        const invoiceInput = { sobjectType: 'Invoice__c', ...invoiceFields };

        //Payment to insert
        const newPaymentFields = {};
        newPaymentFields['Amount__c'] = this.amountToPay;
        newPaymentFields['Payment_Mode__c'] = this.paymentMode; // Make sure this is defined elsewhere
        newPaymentFields['Invoice__c'] = this.recordId;
        newPaymentFields['Comments__c'] = this.comment;
        const paymentInput = { sobjectType: 'Payment__c', ...newPaymentFields };

        const updatedCreditNotesList = [];
        this.creditNoteData.forEach(row => {
            if (this.selectedRowIds.includes(row.Id)) {
                const creditNoteFields = {};
                creditNoteFields['Id'] = row.Id;
                creditNoteFields['Consumed_By_Invoice__c'] = this.recordId;
                creditNoteFields['Invoice__c'] = this.recordId;
                creditNoteFields['Is_used__c'] = row.Available_Amount__c === 0 ? true : false;
                creditNoteFields['Consumed_Amount__c'] = row.Consumed_Amount__c; // or another value
                const creditNoteInput = { sobjectType: 'Credit_Note__c', ...creditNoteFields };
                updatedCreditNotesList.push(creditNoteInput);
            }
        });
        console.log('invoiceInput', JSON.stringify(invoiceInput));
        console.log('paymentInput', JSON.stringify(paymentInput));
        console.log('updatedCreditNotesList', JSON.stringify(updatedCreditNotesList));

        saveInvoicePaymentWithCreditNote({ invoiceInput: invoiceInput, paymentInput: paymentInput, updatedCreditNotesList: updatedCreditNotesList })
            .then((result) => {
                if (result.code) {
                    this.toastNotification('Success', result.message);

                    this.dispatchEvent(new CloseActionScreenEvent());
                } else {
                    this.isSaveClick = false;
                    this.toastNotification('Error', result.message);
                }
            })
            .catch(error => {
                this.isSaveClick = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Error recording payment: ' + error.body.message,
                        variant: 'error'
                    })
                );
            });


    }

    handleSubmit() {
        if (this.isCreditNotePaymentMode) {
            this.isSaveClick = true;
            this.handleSubmitWithCreditNote();
        } else {
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

    toastNotification(title, toastMessage) {
        const evt = new ShowToastEvent({
            title: title,
            message: toastMessage,
            variant: title
        });
        this.dispatchEvent(evt);
    }
}