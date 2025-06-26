import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import clonePriceBook from '@salesforce/apex/ClonePriceBookController.clonePriceBook';
import NAME_FIELD from '@salesforce/schema/Zydus_Price_Book__c.Price_Book_Name__c';
import START_DATE_FIELD from '@salesforce/schema/Zydus_Price_Book__c.Start_Date__c';
import END_DATE_FIELD from '@salesforce/schema/Zydus_Price_Book__c.End_Date__c';
import IS_ACTIVE_FIELD from '@salesforce/schema/Zydus_Price_Book__c.IsActive__c';

export default class ClonePriceBook extends NavigationMixin(LightningElement) {
    @api recordId;
    @track newPriceBookName;
    @track startDate;
    @track endDate;
    @track isActive = true;
    @track priceBook;

    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD, START_DATE_FIELD, END_DATE_FIELD, IS_ACTIVE_FIELD] })
    wiredPriceBook({ error, data }) {
        if (data) {
            this.newPriceBookName = data.fields.Price_Book_Name__c.value + ' - Copy';
            this.startDate = data.fields.Start_Date__c.value;
            this.endDate = data.fields.End_Date__c.value;
            this.isActive = data.fields.IsActive__c.value;
        } else if (error) {
            this.showToast('Error', 'Failed to load original Price Book data.', 'error');
            console.error(error);
        }
    }

    handleNameChange(event) {
        this.newPriceBookName = event.detail.value;
    }
    handleStartDateChange(event) {
        this.startDate = event.detail.value;
    }
    handleEndDateChange(event) {
        this.endDate = event.detail.value;
    }
    handleIsActiveChange() {
        this.isActive = !this.isActive;
    }
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleClone() {
        if (!this.newPriceBookName || !this.startDate || !this.endDate) {
            this.showToast('Error', 'All fields are required.', 'error');
            return;
        }

        clonePriceBook({
            originalPriceBookId: this.recordId,
            newName: this.newPriceBookName,
            startDate: this.startDate,
            endDate: this.endDate,
            isActive: this.isActive
        })
            .then((newPriceBookId) => {
                this.showToast('Success', 'Price Book cloned successfully!', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: newPriceBookId,
                        objectApiName: 'Zydus_Price_Book__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', error.body?.message|| error?.message || 'Something went wrong.', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            })
        );
    }
}