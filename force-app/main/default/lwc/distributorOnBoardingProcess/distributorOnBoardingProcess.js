import { LightningElement, track, wire } from 'lwc';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import STATE_FIELD from '@salesforce/schema/Account.State__c';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import getSuperDistributorOptions from '@salesforce/apex/onboardingController.getSuperDistributorOptions';
import getDistributorOptions from '@salesforce/apex/onboardingController.getDistributorOptions';
import getPriceBookOptions from '@salesforce/apex/onboardingController.getPriceBookOptions';
import DISTRIBUTOR_TYPE_FIELD from '@salesforce/schema/Account.Distributor_Type__c';

export default class DistributorOnBoardingProcess extends LightningElement {
@track distributorName = '';
@track selectedDistributorType = '';
@track contactPerson = '';
@track email = '';
@track mobile = '';
@track address = '';
@track bankDetails = '';
@track panNumber = '';
@track gstNumber = '';
@track salesRep = '';
@track pricebookMapping = '';
@track creditLimit = 0;
@track creditLimitDisplay = '';
@track creditStartDate = '';
@track creditEndDate = '';
@track selectedSubDistributor = '';
@track selectedSuperDistributor = '';
@track zydusMapping = '';
@track selectedState;
@track stateOptions = [];
@track selectedPriceBook = '';
@track distributorId = '';
isDMDisabled = true;
@track Address = '';
@track City = '';
@track Pin = '';
@track firstName = '';
@track lastName = '';
@track accountNumber = '';
@track ifsc = '';
@track bankName = '';
@track selectedHospitals = [];
@track hospitalOptions = [];

salesRepOptions = [
    { label: 'Rep A', value: 'Rep_A' },
    { label: 'Rep B', value: 'Rep_B' }
];

pricebookOptions = [];
distributorOptions = [];
superDistributorOptions = [];

zydusOptions = [
    { label: 'Zone A', value: 'Zone_A' },
    { label: 'Zone B', value: 'Zone_B' }
];

acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.docx'];

handleDistributorNameChange(event) {
    this.distributorName = event.detail.value;
}

handleDistributorTypeChange(event) {
    this.selectedDistributorType = event.detail.value;
    this.isDMDisabled = this.selectedDistributorType !== 'Sub-Distributor';
}

handleContactPersonChange(event) {
    this.contactPerson = event.detail.value;
}

handleEmailChange(event) {
    this.email = event.detail.value;
}

handleMobileChange(event) {
    this.mobile = event.detail.value;
}

handleAddressChange(event) {
    this.address = event.detail.value;
}

handleBankDetailsChange(event) {
    this.bankDetails = event.detail.value;
}

handlePANNumberChange(event) {
    this.panNumber = event.detail.value;
}

handleGSTNumberChange(event) {
    this.gstNumber = event.detail.value;
}

handleSalesRepChange(event) {
    this.salesRep = event.detail.value;
}

handlePricebookMappingChange(event) {
    this.pricebookMapping = event.detail.value;
}

handleCreditLimitChange(event) {
    const rawValue = event.target.value.replace(/[₹,]/g, '');
    const parsed = parseFloat(rawValue);
    if (!isNaN(parsed)) {
        this.creditLimit = parsed;
        this.creditLimitDisplay = event.target.value;
    }
}

handleCreditLimitFocus() {
    this.creditLimitDisplay = this.creditLimit.toString();
}

handleCreditLimitBlur() {
    this.creditLimitDisplay = this.formatINRCurrency(this.creditLimit);
}

handleCreditStartDateChange(event) {
    this.creditStartDate = event.detail.value;
}

handleCreditEndDateChange(event) {
    this.creditEndDate = event.detail.value;
}

handleSubDistributorChange(event) {
    this.selectedSubDistributor = event.detail.value;
}

handleSuperDistributorChange(event) {
    this.selectedSuperDistributor = event.detail.value;
}

handleZydusMappingChange(event) {
    this.zydusMapping = event.detail.value;
}

handleStateChange(event) {
    this.selectedState = event.detail.value;
}

handleSelectedPriceBookChange(event) {
    this.selectedPriceBook = event.detail.value;
}

handleDistributorIdChange(event) {
    this.distributorId = event.detail.value;
}

handleCityChange(event) {
    this.City = event.detail.value;
}

handlePinChange(event) {
    this.Pin = event.detail.value;
}

handleFirstNameChange(event) {
    this.firstName = event.detail.value;
}

handleLastNameChange(event) {
    this.lastName = event.detail.value;
}

handleAccountNumberChange(event) {
    this.accountNumber = event.detail.value;
}

handleIFSCChange(event) {
    this.ifsc = event.detail.value;
}

handleBankNameChange(event) {
    this.bankName = event.detail.value;
}

handleSelectedHospitalsChange(event) {
    this.selectedHospitals = event.detail.value;
}

@wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT }) objectInfo;

@wire(getPicklistValues, {
    recordTypeId: '$objectInfo.data.defaultRecordTypeId',
    fieldApiName: STATE_FIELD
})
wiredPicklistValues({ error, data }) {
    if (data) {
        this.stateOptions = data.values.map(item => ({ label: item.label, value: item.value }));
    } else if (error) {
        console.error('Error fetching state picklist:', error);
    }
}
@wire(getPicklistValues, {
    recordTypeId: '$objectInfo.data.defaultRecordTypeId',
    fieldApiName: DISTRIBUTOR_TYPE_FIELD
})
wiredDistributorTypeValues({ error, data }) {
    if (data) {
        this.distributorTypeOptions = data.values.map(item => ({
            label: item.label,
            value: item.value
        }));
    } else if (error) {
        console.error('Error fetching distributor type picklist:', error);
    }
}

@wire(getSuperDistributorOptions)
wiredSuperDistributorOptions({ error, data }) {
    if (data) {
        this.superDistributorOptions = data.map(item => ({ label: item.Name, value: item.Id }));
    } else if (error) {
        console.error(error);
    }
}

@wire(getDistributorOptions)
wiredDistributorOptions({ error, data }) {
    if (data) {
        this.distributorOptions = data.map(item => ({ label: item.Name, value: item.Id }));
    } else if (error) {
        console.error(error);
    }
}

@wire(getPriceBookOptions)
wiredPriceBookOptions({ error, data }) {
    if (data) {
        this.pricebookOptions = data.map(item => ({ label: item.Name, value: item.Id }));
    } else if (error) {
        console.error(error);
    }
}

handleFocus() {
    this.creditLimitDisplay = this.creditLimit.toString();
}

handleBlur() {
    this.creditLimitDisplay = this.formatINRCurrency(this.creditLimit);
}

handleCreditLimitChange(event) {
    const rawValue = event.target.value.replace(/[₹,]/g, '');
    const parsed = parseFloat(rawValue);
    if (!isNaN(parsed)) {
        this.creditLimit = parsed;
        this.creditLimitDisplay = event.target.value;
    }
}

formatINRCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }).format(amount);
}

handleSubmit() {
    const payload = {
        distributorName: this.distributorName,
        distributorType: this.selectedDistributorType,
        contactPerson: this.contactPerson,
        email: this.email,
        mobile: this.mobile,
        address: this.address,
        bankDetails: this.bankDetails,
        distributorId: this.distributorId,
        panNumber: this.panNumber,
        gstNumber: this.gstNumber,
        salesRep: this.salesRep,
        pricebookMapping: this.pricebookMapping,
        creditLimit: this.creditLimit,
        creditStartDate: this.creditStartDate,
        creditEndDate: this.creditEndDate,
        subDistributorMapping: this.selectedSubDistributor,
        superDistributorMapping: this.selectedSuperDistributor,
        zydusMapping: this.zydusMapping
    };
    this.resetForm();
    console.log('Submitting Distributor:', JSON.stringify(payload));
}

handleSubmitDistributorForApproval() {
    const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')]
        .reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

    if (allValid) {
        this.handleSubmit();
    } else {
        console.warn('Please fill out all required fields.');
    }
}
resetForm() {
    this.distributorName = '';
    this.selectedDistributorType = '';
    this.contactPerson = '';
    this.email = '';
    this.mobile = '';
    this.address = '';
    this.bankDetails = '';
    this.panNumber = '';
    this.gstNumber = '';
    this.salesRep = '';
    this.pricebookMapping = '';
    this.creditLimit = 0;
    this.creditLimitDisplay = '';
    this.creditStartDate = '';
    this.creditEndDate = '';
    this.selectedSubDistributor = '';
    this.selectedSuperDistributor = '';
    this.zydusMapping = '';
    this.selectedState = '';
    this.selectedPriceBook = '';
    this.distributorId = '';
    this.Address = '';
    this.City = '';
    this.Pin = '';
    this.firstName = '';
    this.lastName = '';
    this.accountNumber = '';
    this.ifsc = '';
    this.bankName = '';
    this.selectedHospitals = [];
}

}