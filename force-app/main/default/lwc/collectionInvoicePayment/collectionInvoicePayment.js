import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
import getInvoices from '@salesforce/apex/CollectionCreationClass.getInvoices';
import saveCollectionLineItems from '@salesforce/apex/CollectionCreationClass.saveCollectionLineItems';
export default class CollectionInvoicePayment extends LightningElement {
    @api recordId;
    @api objectApiName;
    @track isLoaded = false;
    collectedAmount = 0
    consumedAmount = 0
    remainingAmount = 0

    paymentMode;
    invoiceColumns = [
        { label: 'Invoice Name', fieldName: 'Name', type: 'text' },
        { label: 'Invoice Date', fieldName: 'InvoiceDate__c', type: 'date' },
        { label: 'Invoice Due Date', fieldName: 'Invoice_Due_Date__c', type: 'date' },
        { label: 'Quantity', fieldName: 'Total_Quantity__c', type: 'number' },
        { label: 'Amount', fieldName: 'Total_Amount__c', type: 'currency' },
    ];
    @track invoices = [];
    @track invoicesLineItem = [];
    filteredInvoices = [];
    selectedRowIds = [];

    DEBOUNCE_DELAY = 500;
    timeoutId;
    refreshHandlerId;

    connectedCallback() {
        this.isLoaded = true;
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
        }
        this.timeoutId = setTimeout(() => {
            if (this.recordId) {
                console.log('connectedCallback 3>', this.recordId);
                this.getInvoiceList();
            }
        }, this.DEBOUNCE_DELAY);

    }


    getInvoiceList() {
        // If you need to force refresh the data, you could call the Apex method directly
        getInvoices({ objectApiName: this.objectApiName, recordId: this.recordId })
            .then(data => {
                this.processInvoiceData(data);
            })
            .catch(error => {
                this.isLoaded = false;
                this.error = error;
                console.log('getInvoiceList Error:', error);
                this.invoices = [];
                this.invoicesLineItem = [];
            });
    }

    // Shared data processing logic
    processInvoiceData(data) {
        this.collectedAmount = data.collection?.Collected_Amount__c;
        this.consumedAmount = data.collection?.Consumed_Amount__c;
        this.remainingAmount = data.collection?.Remaining_Amount__c;
        this.paymentMode = data.collection?.Collected_Mode__c;

        if (data.invoiceList?.length > 0) {
            this.invoices = data.invoiceList;
            this.invoicesLineItem = this.transformInvoiceData(data.invoiceList);
        } else {
            this.invoices = [];
            this.invoicesLineItem = [];
        }
        this.isLoaded = false;
    }

    // Data transformation logic
    transformInvoiceData(invoiceList) {


        return invoiceList.map(invoice => {

            const pendingAmount = invoice.Total_Pending_Amount__c || 0;
            let collected = 0;

            if (this.remainingAmount > 0) {
                // Allocate the smaller of remaining or pending amount
                collected = Math.min(pendingAmount, this.remainingAmount);
                this.remainingAmount -= collected;
            }
            return {
                invoiceId: invoice.Id,
                invoiceUrl: '/' + invoice.Id,
                invoiceName: invoice.Name,
                invoiceDate: invoice.InvoiceDate__c,
                invoiceDueDate: invoice.Invoice_Due_Date__c,
                invoiceQuantity: invoice.Total_Quantity__c,
                invoiceTotalAmount: invoice.Total_Amount__c,
                invoiceLastCollectedAmount: invoice.Total_Collected_Amount__c || 0,
                invoicePendingAmount: invoice.Total_Pending_Amount__c,
                collectedAmount: collected, // Default value
            };
        });
    }



    get isInvoicesLineItem() {
        return this.invoicesLineItem.length > 0 ? true : false;
    }

    get isInvoicesSave() {
        if (this.isSaveClick) {
            return true;
        }
        return this.isInvoicesLineItem ? false : true;
    }


    get calCollectedAmount() {
        let totalMarkedAmount = 0;

        // Loop through marked invoices
        for (let invoiceId in this.invoicesLineItem) {
            if (this.invoicesLineItem[invoiceId]) {
                const enteredAmount = parseFloat(this.invoicesLineItem[invoiceId].collectedAmount) || 0;
                totalMarkedAmount += enteredAmount;
            }
        }

        const totalCollected = parseFloat(this.collectedAmount) - parseFloat(this.consumedAmount);
        const remaining = totalCollected - totalMarkedAmount;

        return remaining;

    }
    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRowIds = selectedRows.map(row => row.Id);
        console.log('Selected Invoice IDs:', JSON.stringify(this.selectedRowIds));
    }

    handleAmountChange(event) {
        const index = event.target.dataset.index;
        const amount = event.target.value;
        const updatedInvoices = [...this.invoicesLineItem];
        if (amount > updatedInvoices[index].invoicePendingAmount) {

            this.toastNotification('Error', 'Please enter an amount less than or equal to the pending amount.');
            updatedInvoices[index].collectedAmount = 0;
            this.invoicesLineItem = updatedInvoices;
            return;
        }
        updatedInvoices[index].collectedAmount = amount;
        this.invoicesLineItem = updatedInvoices;

    }
    handleChangeRemark(event) {
        const index = event.target.dataset.index;
        const remark = event.target.value;
        const updatedInvoices = [...this.invoicesLineItem];

        updatedInvoices[index].invoiceRemark = remark;
        this.invoicesLineItem = updatedInvoices;

    }

    handleClose(event) {
        // Close the modal window and display a success toast
        this.dispatchEvent(new CloseActionScreenEvent());

    }
    isSaveClick = false;
    handleSave(event) {
        this.isSaveClick = true;
        const collectionLineitems = [];
        const invoiceUpdateList = [];
        const paymentInsertList = [];
        let errorList = [];

        for (let invoiceId in this.invoicesLineItem) {
            const item = this.invoicesLineItem[invoiceId];
            const collected = parseFloat(item.collectedAmount);
            const pending = parseFloat(item.invoicePendingAmount);

            console.log(`Checking: ${item.invoiceName}, Collected: ${collected}, Pending: ${pending}`);

            if (item && collected > 0) {
                if (collected > pending) {
                    errorList.push(`• ${item.invoiceName}: Entered amount (${collected}) exceeds pending amount (${pending})`);
                }
            }
        }
        console.log(JSON.stringify(errorList));

        if (errorList.length > 0) {
            const errorMessage = 'Please correct the following:\n' + errorList.join('\n');
            console.log(errorMessage)
            this.toastNotification('Error', errorMessage);
            return;
        }

        for (let invoiceId in this.invoicesLineItem) {
            const item = this.invoicesLineItem[invoiceId];

            if (item && item.collectedAmount > 0) {
                const collectedAmount = item.collectedAmount;


                //Collection Line Items
                const collectionLineitemFields = {};
                collectionLineitemFields['Collected_Amount__c'] = collectedAmount;
                collectionLineitemFields['Collection__c'] = this.recordId;
                collectionLineitemFields['Invoice__c'] = item.invoiceId;
                collectionLineitemFields['Remarks__c'] = item.invoiceRemark;
                const collectionInput = { sobjectType: 'Collection_Line_Item__c', ...collectionLineitemFields };
                collectionLineitems.push(collectionInput);

                //invoice to Update
                const totalAmount = item.invoiceTotalAmount;
                const lastCollectedAmount = item.invoiceLastCollectedAmount;

                const totalCollected = parseFloat(lastCollectedAmount) + parseFloat(collectedAmount);
                console.log('totalCollected',totalCollected);
                const invoiceFields = {};
                invoiceFields['Id'] = item.invoiceId;
                invoiceFields['Total_Collected_Amount__c'] = totalCollected;
                invoiceFields['Payment_Status__c'] = totalCollected === totalAmount ? 'Fully Paid' : 'Partially Paid';
                invoiceFields['Invoice_Closed__c'] = true;
                const invoiceInput = { sobjectType: 'Invoice__c', ...invoiceFields };
                invoiceUpdateList.push(invoiceInput);

                //Payment to insert
                const newPaymentFields = {};
                newPaymentFields['Amount__c'] = collectedAmount;
                newPaymentFields['Payment_Mode__c'] = this.paymentMode, // Make sure this is defined elsewhere
                    newPaymentFields['Invoice__c'] = item.invoiceId;
                const paymentInput = { sobjectType: 'Payment__c', ...newPaymentFields };
                paymentInsertList.push(paymentInput);

            }
        }
        console.log('paymentInsertList>>', JSON.stringify(paymentInsertList));

        if (collectionLineitems.length > 0) {
            // Example: call Apex method
            saveCollectionLineItems({ lineItems: collectionLineitems, invoiceUpdateList: invoiceUpdateList, paymentInsertList: paymentInsertList })
                .then((result) => {
                    console.log('saveCollectionLineItems Result:', result);
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
                    // Error handling
                    console.log('saveCollectionLineItems Error:', error);
                    this.toastNotification('Error', error);
                });
        } else {
            this.toastNotification('Error', 'Please enter a Settlement collected amount');
        }

    }

    async refreshData() {
        await refreshApex(this.wiredInvoices);
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