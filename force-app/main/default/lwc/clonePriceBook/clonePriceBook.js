import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import clonePriceBook from '@salesforce/apex/ClonePriceBookController.clonePriceBook';

export default class ClonePriceBook extends NavigationMixin(LightningElement) {
    @api recordId;
    @track startDate;
    @track endDate;
    @track isActive = true;
    @track priceBook;
    @track dealer;
    @track hospital;
    @track recordType;
    recordTypeId

    @wire(getRecord, {recordId: '$recordId',layoutTypes: ['Full'],odes: ['View']})
    wiredPriceBook({ error, data }) {
        if (data) {
            console.log('data:', data);
            this.startDate = data.fields.Start_Date__c.value;
            this.endDate = data.fields.End_Date__c.value;
            this.isActive = data.fields.IsActive__c.value;
            this.dealer = data.fields.Dealer_Name__c.value;
            this.hospital = data.fields.Hospital_Name__c.value;
            this.recordType = data.recordTypeInfo?.name;
            this.recordTypeId = data.recordTypeInfo?.recordTypeId;

        } else if (error) {
            this.showToast('Error', 'Failed to load original Price Book data.', 'error');
            console.error(error);
        }
    }
    get recordTypeName() {
        return this.recordType == 'Distributor' ? true : false;
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
    handleDealerNameChange(event) {
        this.dealer = event.detail.value;
    }
    handleHospitalNameChange(event) {
        this.hospital = event.detail.value;
    }
    handleClone() {
        if (!this.startDate || (!this.dealer && !this.hospital)) {
            this.showToast('Error', 'All fields are required', 'error');
            return;
        }

        clonePriceBook({
            originalPriceBookId: this.recordId,
            startDate: this.startDate,
            endDate: this.endDate,
            isActive: this.isActive,
            dealer: this.dealer,
            hospital: this.hospital,
            recordTypeId: this.recordTypeId,
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
                this.showToast('Error', error.body?.message || error?.message || 'Something went wrong.', 'error');
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