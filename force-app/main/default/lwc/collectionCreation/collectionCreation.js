import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { createRecord } from 'lightning/uiRecordApi';
import getCollectionRecordTypes from '@salesforce/apex/CollectionCreationClass.getCollectionRecordTypes';
import getUserAccountsAndHospitals from '@salesforce/apex/InvoiceCreationController.getUserAccountsAndHospitals';
import getPaymentModePicklistValues from '@salesforce/apex/InvoiceCreationController.getPaymentModePicklistValues';
import fetchCollections from '@salesforce/apex/CollectionCreationClass.fetchCollections';

export default class CollectionCreation extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    invoiceCreationOptions = [
        { label: 'Hospital', value: 'hospital' },
        { label: 'Channel Partner', value: 'channelPartner' }
    ]
    @track isChannelPartnerMode = false;
    @track isHospitalMode = true;
    @track selectedInvoiceCreationType = 'hospital';
    @track accountOptions = [];
    @track invoiceTypeOptions = [];
    @track hospitalOptions = [];
    recordTypeOptions = [];
    recordTypeId;
    selectedHospitalId

    @track channelPartnerOptions = [];

    selectedHospital;
    selectedChannelPartner;
    invoiceType;
    collectionList = [];
    collectionColumns;
    collectionColumnsAccount = [
        { label: 'Name', fieldName: 'CollectionRecordUrl__c', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' } },
        { label: 'Collected Mode', fieldName: 'Collected_Mode__c', type: 'text' },
        { label: 'Collected Amount', fieldName: 'Collected_Amount__c', type: 'currency' },
        { label: 'Consumed Amount', fieldName: 'Consumed_Amount__c', type: 'currency' },
        { label: 'Remaining Amount', fieldName: 'Remaining_Amount__c', type: 'currency' },
        { label: 'Status', fieldName: 'Available_Status__c', type: 'text' },
        { label: 'Remarks', fieldName: 'Remarks__c', type: 'text' },

    ];

    collectionColumnsHospital = [
        { label: 'Name', fieldName: 'CollectionRecordUrl__c', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' } },
        { label: 'Collected Mode', fieldName: 'Collected_Mode__c', type: 'text' },
        { label: 'Collected Amount', fieldName: 'Collected_Amount__c', type: 'currency' },
        { label: 'Consumed Amount', fieldName: 'Consumed_Amount__c', type: 'currency' },
        { label: 'Remaining Amount', fieldName: 'Remaining_Amount__c', type: 'currency' },
        { label: 'Status', fieldName: 'Available_Status__c', type: 'text' },
        { label: 'Remarks', fieldName: 'Remarks__c', type: 'text' },
    ];

    @track paymentModeOptions = [];
    paymentMode;

    isLoaded = false;

    handleInvoiceCreationTypeChange(event) {
        this.selectedInvoiceCreationType = event.detail.value;
        this.isHospitalMode = this.selectedInvoiceCreationType === 'hospital';
        this.isChannelPartnerMode = this.selectedInvoiceCreationType === 'channelPartner';
        if (this.isHospitalMode) {
            this.collectionColumns = this.collectionColumnsHospital;
            this.recordTypeId = this.recordTypeOptions.find(rt => rt.label === 'Hospital').value;
        }
        if (this.isChannelPartnerMode) {
            this.collectionColumns = this.collectionColumnsAccount;
            this.recordTypeId = this.recordTypeOptions.find(rt => rt.label === 'Master').value;
        }
        console.log('this.recordTypeId>>', this.recordTypeId);
    }

    @wire(getCollectionRecordTypes)
    wiredRecordTypes({ error, data }) {
        if (data) {
            this.recordTypes = { data };
            console.log('wiredRecordTypes', JSON.stringify(this.recordTypes));
            this.recordTypeOptions = data.map(rt => ({
                label: rt.name,
                value: rt.id
            }));
            console.log('recordTypeOptions', JSON.stringify(this.recordTypeOptions));

        } else if (error) {
            this.recordTypes = { error };
            console.error('Error loading record types:', error);
        }
    }

    @wire(getUserAccountsAndHospitals)
    wiredAccountsAndHospitals({ error, data }) {
        console.log('Wired method called');
        if (data) {
            console.log('Result:', data);
            const accountList = data.accounts;
            const invoiceTypes = data.invoiceTypes;

            if (accountList.length > 0) {

                this.invoiceTypeOptions = invoiceTypes.map(type => ({
                    label: type,
                    value: type
                }));

                this.selectedInvoiceType = this.invoiceTypeOptions.length > 0
                    ? this.invoiceTypeOptions[0].value
                    : null;
            }

            this.showComponent = true;

            this.accountOptions = accountList.map(acc => ({
                label: acc.Name,
                value: acc.Id
            }));

            this.hospitalOptions = Object.entries(data.hospitals).map(([id, name]) => ({
                label: name,
                value: id
            }));

            getPaymentModePicklistValues()
                .then(result => {
                    this.paymentModeOptions = result.map(value => ({
                        label: value,
                        value: value
                    }));
                })
                .catch(error => {
                    console.error('Error fetching payment mode picklist:', error);
                });

        } else if (error) {
            this.showComponent = false;
            this.errorMessage = 'Error loading accounts and hospitals.';
            console.error('Error loading accounts and hospitals', error);
        }

        this.isLoaded = false;
    }

    collectedAmount = 0;

    invoiceColumns = [
        { label: 'Invoice Name', fieldName: 'Name', type: 'text' },
        { label: 'Invoice Date', fieldName: 'InvoiceDate__c', type: 'date' },
        { label: 'Invoice Due Date', fieldName: 'Invoice_Due_Date__c', type: 'date' },
        { label: 'Quantity', fieldName: 'Total_Quantity__c', type: 'number' },
        { label: 'Amount', fieldName: 'Total_Amount__c', type: 'currency' },
    ];

    remark;
    handleChangeRemark(event) {
        this.remark = event.detail.value;
    }

    handleHospitalChange(event) {
        this.selectedHospitalId = event.detail.value;
        console.log('this.selectedHospitalId', this.selectedHospitalId);
        this.collectionList = [];
        this.fetchCollections(this.selectedHospitalId);
    }

    fetchCollections(selectedRecordId) {
        fetchCollections({ selectedRecordId: selectedRecordId })
            .then(result => {
                console.log('FetchCollections Result: ', result);
                this.collectionList = result;
            })
            .catch(error => {
                console.error('FetchCollections Error:', error);

            });
    }

    handleChannelPartnerSelect(event) {
        this.selectedChannelPartner = event.detail.value;
        console.log('this.selectedChannelPartner', this.selectedChannelPartner);
        this.collectionList = [];
        this.fetchCollections(this.selectedChannelPartner);
    }
    get collectionListShow() {
        return this.collectionList.length > 0 ? true : false;
    }
    handleChangeAmount(event) {
        console.log('handleChangeAmount', event.detail.value);
        this.collectedAmount = event.detail.value;
        console.log('collectedAmount', this.collectedAmount);
    }

    handlePaymentModeChange(event) {
        this.paymentMode = event.detail.value;
    }
    get isModeSelected() {
        return this.paymentMode != null ? false : true;
    }
    get isCollectedAmountCheck() {
        let checkIsTrue = false;
        if (this.isHospitalMode) {
            checkIsTrue = this.selectedHospitalId != null ? false : true;
        } else
            if (this.isChannelPartnerMode) {
                checkIsTrue = this.selectedChannelPartner != null ? false : true;
            }

        return this.collectedAmount > 0 && !checkIsTrue ? false : true;
    }
    handlePaymentSettlement(event) {
        if (this.collectedAmount === 0 || this.collectedAmount == null) {
            this.toastNotification('Error', 'Please enter a payment settlement amount');
            return;
        }
    }

    handleSave(event) {
        const collectionFields = {};
        if (this.isHospitalMode) {
            collectionFields['Hospital__c'] = this.selectedHospitalId;
        } else
            if (this.isChannelPartnerMode) {
                collectionFields['Account__c'] = this.selectedChannelPartner;
            }
        collectionFields['Collected_Amount__c'] = this.collectedAmount;
        collectionFields['Collected_Mode__c'] = this.paymentMode;
        collectionFields['RecordTypeId'] = this.recordTypeId;
        collectionFields['Remarks__c'] = this.remark;
        collectionFields['Status__c'] = 'Draft';
        const collectionInput = { apiName: 'Collection__c',fields: collectionFields };

        console.log('collectionInput:', JSON.stringify(collectionInput));

        createRecord(collectionInput)
            .then(collection => {
                this.toastNotification('Success', 'Collection record is created successfully');
                
                if(collection.id){
                 
                    this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: collection.id,
                        objectApiName: 'Collection__c',
                        actionName: 'view'
                    }
                });

                   this.resetValues();
                }
                

            })
            .catch(error => {
                const errors = error.body ? error.body.message : error.message;
                this.toastNotification('Error', errors);
            });
    }

    resetValues() {
        this.selectedHospitalId = null;
        this.selectedChannelPartner= null;
        this.paymentMode = null;
        this.collectedAmount = null;
        this.remark =null;
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