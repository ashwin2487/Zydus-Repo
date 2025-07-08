import { LightningElement, track, wire } from 'lwc';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import STATE_FIELD from '@salesforce/schema/Account.State__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import getSuperDistributorOptions from '@salesforce/apex/onboardingController.getSuperDistributorOptions';
import getDistributorOptions from '@salesforce/apex/onboardingController.getDistributorOptions';
import getHospitalOptions from '@salesforce/apex/onboardingController.getHospitalOptions';
import getSubDistributorOptions from '@salesforce/apex/onboardingController.getSubDistributorOptions';
import getPriceBookOptions from '@salesforce/apex/onboardingController.getPriceBookOptions';
import getDistributorTypePicklistValues from '@salesforce/apex/onboardingController.getDistributorTypePicklistValues';
import fetchUserDistributorHierarchy from '@salesforce/apex/onboardingController.fetchUserDistributorHierarchy';
import getDistributorsBySuper from '@salesforce/apex/onboardingController.getDistributorsBySuper';
import getSubDistributorsByDistributor from '@salesforce/apex/onboardingController.getSubDistributorsByDistributor';
import USER_ID from '@salesforce/user/Id';
import getZydusAccounts from '@salesforce/apex/onboardingController.getZydusAccounts';
import getZydusSalesRepPositions from '@salesforce/apex/onboardingController.getZydusSalesRepPositions';
import submitDistributorForApproval from '@salesforce/apex/DistributorOnboardingController.submitDistributorForApproval';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createHospitalRecord from '@salesforce/apex/HospitalOnboardingController.createHospitalRecord';
import getLatestDistributorId from '@salesforce/apex/onboardingController.getLatestDistributorId';
import getLatestHospitalId from '@salesforce/apex/onboardingController.getLatestHospitalId';
const MAX_FILE_SIZE = 5 * 1024 * 1024;
const MAX_TOTAL_RAW_BYTES = MAX_FILE_SIZE * 6;
import getProductOptions from '@salesforce/apex/onboardingController.getProductOptions';

export default class OnboardingProcess extends LightningElement {

    states = [
        { label: "Andaman and Nicobar Islands", value: "AN" },
        { label: "Andhra Pradesh", value: "AP" },
        { label: "Arunachal Pradesh", value: "AR" },
        { label: "Assam", value: "AS" },
        { label: "Bihar", value: "BR" },
        { label: "Chandigarh", value: "CH" },
        { label: "Chhattisgarh", value: "CG" },
        { label: "Dadra and Nagar Haveli and Daman and Diu", value: "DN" },
        { label: "Delhi", value: "DL" },
        { label: "Goa", value: "GA" },
        { label: "Gujarat", value: "GJ" },
        { label: "Haryana", value: "HR" },
        { label: "Himachal Pradesh", value: "HP" },
        { label: "Jammu and Kashmir", value: "JK" },
        { label: "Jharkhand", value: "JH" },
        { label: "Karnataka", value: "KA" },
        { label: "Kerala", value: "KL" },
        { label: "Ladakh", value: "LA" },
        { label: "Lakshadweep", value: "LD" },
        { label: "Madhya Pradesh", value: "MP" },
        { label: "Maharashtra", value: "MH" },
        { label: "Manipur", value: "MN" },
        { label: "Meghalaya", value: "ML" },
        { label: "Mizoram", value: "MZ" },
        { label: "Nagaland", value: "NL" },
        { label: "Odisha", value: "OR" },
        { label: "Punjab", value: "PB" },
        { label: "Rajasthan", value: "RJ" },
        { label: "Sikkim", value: "SK" },
        { label: "Tamil Nadu", value: "TN" },
        { label: "Telangana", value: "TS" },
        { label: "Tripura", value: "TR" },
        { label: "Uttar Pradesh", value: "UP" },
        { label: "Uttarakhand", value: "UK" },
        { label: "West Bengal", value: "WB" },
        { label: "Puducherry", value: "PY" }
    ];
    @track selectedPriceBook = '';
    @track distributorId = '';
    @track selectedOnboardingType = '';
    @track isDistributorSelected = false;
    @track isHospitalSelected = false;
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
    isDMDisabled = true;
    isSDMDisabled = true;
    @track Address = '';
    @track shipAddress = '';
    @track city = '';
    @track pin = '';
    @track firstName = '';
    @track lastName = '';
    @track accountNumber = '';
    @track ifsc = '';
    @track bankName = '';
    @track selectedHospitals = [];
    @track selectedProducts = [];
    @track hospitalOptions = [];
    @track productOptions = [];
    @track pricebookOptions = [];
    @track distributorOptions = [];
    @track superDistributorOptions = [];
    @track subDistributorOptions = [];
    @track zydusOptions = [];
    @track isUploadModalOpen = false;
    @track hospitalName = '';
    @track hospRegistrationNumber = '';
    @track billingAddress = '';
    @track hospitalId = '';
    @track shipTitle = '';
    @track shippingAddress = '';
    @track selectedShipState = '';
    @track shipPin = '';
    @track shipCity = '';
    @track isShippingSame = false;
    @track dlNo = '';
    @track doctorName = '';
    @track paymentTerm = '';
    @track invoiceComment = '';
    @track dlExpiryDate;
    @track ccEmail = '';
    @track hospGroup = '';
    @track selectedChannelPartnerType = '';
    @track selectedChannelPartner = '';
    @track channelPartnerOptions = [];
    @track selectedSuperDistributor = '';
    @track selectedDistributor = '';
    @track selectedSubDistributor = '';
    @track selectedChannelPartnerId = '';
    @track selectedDistributorId = '';
    @track selectedSuperDistributorId = '';
    @track selectedSubDistributorId = '';
    @track isLoading = false;
    @track msg;
    @track phyziiId;
    mappingSelectedSuperDistributorId = '';
    mappingSelectedDistributorId = '';
    mappingSelectedSubDistributorId = '';
    @track commentOptionSelected = [];
    mappingDistributorTypeOptions = [];
    mappingChannelPartnerOptions = [];
    @track paymentTermOptions = [
        { label: 'Advance Payment', value: 'Advance' },
        { label: 'Next 15 Days', value: 'Net15' },
        { label: 'Next 30 Days', value: 'Net30' },
        { label: 'Cash on Delivery', value: 'COD' }
    ];
    @track commentOptions = [
        { label: 'PO Level', value: 'POL' },
        { label: 'SO Level', value: 'SOL' },
        { label: 'DC Level', value: 'DCL' },
        { label: 'Invoice Level', value: 'INL' }
    ];
    @track documentUploads = [
        {
            key: 'pan',
            label: 'Pan Certificate*',
            checkboxLabel: 'I confirm Pan document is uploaded (5 MB Max.)',
            file: null,
            fileName: '',
            confirmed: false
        },
        {
            key: 'gst',
            label: 'GST Certificate*',
            checkboxLabel: 'I confirm GST document is uploaded (5 MB Max.)',
            file: null,
            fileName: '',
            confirmed: false
        },
        {
            key: 'bank',
            label: 'Bank Gaurantee*',
            checkboxLabel: 'I confirm Bank Gaurantee document is uploaded (5 MB Max.)',
            file: null,
            fileName: '',
            confirmed: false
        },
        {
            key: 'license',
            label: 'Drug License Certificate*',
            checkboxLabel: 'I confirm Drug License document is uploaded (5 MB Max.)',
            file: null,
            fileName: '',
            confirmed: false
        },
        {
            key: 'cheque',
            label: 'Cancelled Cheque*',
            checkboxLabel: 'I confirm Cancelled Cheque is uploaded (5 MB Max.)',
            file: null,
            fileName: '',
            confirmed: false
        },
        {
            key: 'agreement',
            label: 'Agreement Copy*',
            checkboxLabel: 'I confirm Agreement Copy is uploaded (5 MB Max.)',
            file: null,
            fileName: '',
            confirmed: false
        }
    ];
    drugLicenceNumber = '';
    validTillDate = '';

    onboardingOptions = [
        { label: 'Distributor Onboarding', value: 'distributor' },
        { label: 'Hospital Onboarding', value: 'hospital' }
    ];


    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.docx'];

    openUploadModal() {
        this.isUploadModalOpen = true;
        console.log('isUploadModalOpen - - ', this.isUploadModalOpen);
    }

    closeUploadModal() {
        this.isUploadModalOpen = false;
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        const key = event.target.dataset.key;

        if (!file) { return; }

        if (file.size > MAX_FILE_SIZE) {
            alert(`"${file.name}" is too large. Maximum per-file size is 5 MB.`);
            return;
        }

        const currentTotal = this.documentUploads.reduce(
            (sum, d) => sum + (d.file ? d.file.size : 0),
            0
        );
        if (currentTotal + file.size > MAX_TOTAL_RAW_BYTES) {
            alert('Adding this file would exceed the total 30 MB limit across all documents.');
            return;
        }

        const isAccepted = this.acceptedFormats.some(ext =>
            file.name.toLowerCase().endsWith(ext)
        );
        if (!isAccepted) {
            alert('Unsupported file type. Allowed: PDF, PNG, JPG, JPEG, DOCX.');
            return;
        }

        const reader = new FileReader();
        reader.onloadend = () => {
            const base64 = reader.result.split(',')[1];
            this.documentUploads = this.documentUploads.map(d => {
                if (d.key === key) {
                    return {
                        ...d,
                        file: file,
                        fileName: file.name,
                        fileData: base64,
                        confirmed: true
                    };
                }
                return d;
            });
        };
        reader.onerror = () => {
            console.error('File reading error', reader.error);
            alert('There was an error reading the file.');
        };
        reader.readAsDataURL(file);
    }

    removeFile(event) {
        const key = event.target.dataset.key;
        this.documentUploads = this.documentUploads.map(d => {
            if (d.key === key) {
                return {
                    ...d,
                    file: null,
                    fileName: '',
                    fileData: null,
                    confirmed: false
                };
            }
            return d;
        });
        const input = this.template.querySelector(`input[data-key="${key}"]`);
        if (input) { input.value = null; }
    }

    validateAndCloseModal() {
        const allConfirmed = this.documentUploads.every(d => d.confirmed && d.fileData);
        if (!allConfirmed) {
            alert('Please upload all documents before proceeding.');
            return;
        }
        this.closeUploadModal();
    }

    handleOnboardingTypeChange(event) {
        this.selectedOnboardingType = event.detail.value;
        this.isDistributorSelected = this.selectedOnboardingType === 'distributor';
        this.isHospitalSelected = this.selectedOnboardingType === 'hospital';
    }

    handleDistributorNameChange(event) {
        this.distributorName = event.detail.value;
    }

    handleDrugLicenceNumberChange(event) {
        const value = event.target.value;
        this.drugLicenceNumber = value;

        const msg = this.validateFields('drugLicenceNumber', 'submit');

        const inputCmp = this.template.querySelector('[data-id="drugLicenceInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }


    handleValidTillDateChange(event) {
        this.validTillDate = event.target.value;
        const msg = this.validateFields('validTillDate', 'submit');
        const inputCmp = this.template.querySelector('[data-id="validTillDateInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: STATE_FIELD
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.stateOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }

    @wire(getSuperDistributorOptions)
    wiredSuperDistributorOptions({ error, data }) {
        if (data) {
            this.superDistributorOptions = data.map(item => ({
                label: item.Name,
                value: item.Id
            }));
        } else if (error) {
            console.error('Error fetching Super Distributor options:', error);
        }
    }

    @wire(getDistributorOptions)
    wiredDistributorOtions({ error, data }) {
        console.log('data is ', error);
        if (data) {
            console.log('data is ', data);
            this.distributorOptions = data.map(item => ({
                label: item.Name,
                value: item.Id
            }));
        } else if (error) {
            console.error(error);
        }
    }
    @wire(getDistributorTypePicklistValues)
    wiredPicklist({ error, data }) {
        if (data) {
            this.distributorTypeOptions = data.map(value => ({
                label: value,
                value: value
            }));
        } else if (error) {
            console.error('Error fetching Distributor Type values', error);
        }
    }
    @wire(getSubDistributorOptions)
    wiredSubDistributorOtions({ error, data }) {
        if (data) {
            this.subDistributorOptions = data.map(item => ({
                label: item.Name,
                value: item.Id
            }));
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getZydusAccounts)
    wiredZydusAccounts({ error, data }) {
        if (data) {
            this.zydusOptions = data.map(account => ({
                label: account.Name,
                value: account.Id
            }));
        } else if (error) {
            console.error('Error fetching Zydus Accounts', error);
        }
    }



    handleSUPDSelection(event) {
        this.selectedSuperDistributor = event.detail.value;
    }

    handleDistributorChange(event) {
        this.selectedDistributor = event.detail.value;
    }

    handleAddressChange(event) {
        this.address = event.detail.value;
    }

    handleCityChange(event) {
        this.city = event.detail.value;
        const msg = this.validateFields('city', 'submit');
        const inputCmp = this.template.querySelector('[data-id="cityInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleShipAddressChange(event) {
        this.shipAddress = event.detail.value;
    }

    handlePinChange(event) {
        this.pin = event.detail.value;
        const msg = this.validateFields('pin', 'submit');
        const inputCmp = this.template.querySelector('[data-id="pinInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleFirstNameChange(event) {
        this.firstName = event.detail.value;
    }

    handleLastNameChange(event) {
        this.lastName = event.detail.value;
    }

    handleAccountNumberChange(event) {
        this.accountNumber = event.detail.value;
        const msg = this.validateFields('accountNumber', 'submit');
        const inputCmp = this.template.querySelector('[data-id="accountNumberInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }


    handleIFSCChange(event) {
        this.ifsc = event.detail.value?.toUpperCase();
        const msg = this.validateFields('ifsc', 'submit');
        const inputCmp = this.template.querySelector('[data-id="ifscInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }


    handleBankNameChange(event) {
        this.bankName = event.detail.value;
    }

    handlePanNumberChange(event) {
        this.panNumber = event.detail.value;
        const msg = this.validateFields('panNumber', 'submit');
        const inputCmp = this.template.querySelector('[data-id="panInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleGSTNumberChange(event) {
        this.gstNumber = event.detail.value;
        const msg = this.validateFields('gstNumber', 'submit');
        const inputCmp = this.template.querySelector('[data-id="gstInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleStartDateChange(event) {
        this.creditStartDate = event.target.value;
        const msg = this.validateFields('creditDates', 'submit');
        const inputCmp = this.template.querySelector('[data-id="creditStartDateInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleEndDateChange(event) {
        this.creditEndDate = event.target.value;
        const msg = this.validateFields('creditDates', 'submit');
        const inputCmp = this.template.querySelector('[data-id="creditEndDateInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    @wire(getPriceBookOptions)
    wiredPriceBookOtions({ error, data }) {
        if (data) {
            this.pricebookOptions = data.map(item => ({
                label: item.Price_Book_Name__c,
                value: item.Id
            }));
        } else if (error) {
            console.error(error);
        }
    }
    handlePriceBookChange(event) {
        this.selectedPriceBook = event.detail.value;
        console.log('selected price book is ' + this.selectedPriceBook);
    }
    creditLimit = 0;
    creditLimitDisplay = '';

    formatINRCurrency(amount) {
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(amount);
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
        } else {

            this.creditLimitDisplay = rawValue;
        }
    }

    handleSalesRepChange(event) {
        this.salesRep = event.detail.value;
    }

    @wire(getHospitalOptions)
    wiredHospitalOtions({ error, data }) {
        if (data) {
            this.hospitalOptions = data.map(item => ({
                label: item.Name,
                value: item.Id
            }));
        } else if (error) {
            console.error(error);
        }
    }
    @wire(getProductOptions)
    wiredProductOptions({ error, data }) {
        if (data) {
            this.productOptions = data.map(item => ({
                label: item.Name,
                value: item.Id
            }));
        } else if (error) {
            console.error(error);
        }
    }
    @wire(getZydusSalesRepPositions)
    wiredZydusContacts({ error, data }) {
        if (data) {
            this.salesRepOptions = data.map(contact => ({
                label: contact.Name,
                value: contact.Id
            }));
        } else if (error) {
            console.error('Error fetching Zydus Contacts', error);
        }
    }
    handleZydusMappingChange(event) {
        this.zydusMapping = event.detail.value;
    }
    handleHospitalChange(event) {
        this.selectedHospitals = event.detail.value;
    }
    handleProductChange(event) {
        this.selectedProducts = event.detail.value;
    }
    handleMobileChange(event) {
        this.mobile = event.target.value;
        const msg = this.validateFields('mobile', 'submit');
        const inputCmp = this.template.querySelector('[data-id="mobileInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }
    handleStateChange(event) {
        this.selectedState = event.detail.value;
        console.log('selectedState', this.selectedState);
        this.updateDistributorId();
    }

    handleSelectDTChange(event) {
        this.selectedDistributor = '';
        this.selectedDistributorId = '';
        this.selectedSuperDistributor = '';
        this.selectedSuperDistributorId = '';
        this.selectedSubDistributor = '';
        this.selectedSubDistributorId = '';
        this.selectedDistributorType = event.detail.value;
        this.isDMDisabled = this.selectedDistributorType !== 'Sub Distributor';
        this.isSDMDisabled = this.selectedDistributorType === 'Super Distributor';
        this.updateDistributorId();
    }

    fiveDigitDistributorNumber;

    @wire(getLatestDistributorId)
    wiredLatestDistributorId({ error, data }) {
        if (data) {
            console.log('data', data);
            const match = data.match(/\d+$/);
            if (match) {
                this.fiveDigitDistributorNumber = match[0].padStart(5, '0');
            }
        } else if (error) {
            console.error('Error fetching latest distributor ID:', error);
        }
    }

    updateDistributorId() {
        if (this.selectedState && this.selectedDistributorType && this.fiveDigitDistributorNumber !== undefined) {

            const stateObj = this.states.find(state => state.label === this.selectedState);


            const stateCode = stateObj ? stateObj.value : '';


            const distributorTypeCode = 'D';
            const nextNumber = String(parseInt(this.fiveDigitDistributorNumber, 10) + 1).padStart(5, '0');

            this.distributorId = stateCode
                ? `${stateCode}${distributorTypeCode}${nextNumber}`
                : '';

        } else {
            this.distributorId = '';
        }
    }

    validateFields(field, mode = 'submit') {
        switch (field) {
            case 'drugLicenceNumber':
                if (this.drugLicenceNumber?.length > 20)
                    return 'DL Number cannot be more than 20 characters.';
                if (mode === 'submit' && this.drugLicenceNumber?.length !== 20)
                    return 'Drug Licence Number must be 20 characters long.';
                break;
            case 'dlNo':
                if (this.dlNo?.length > 20)
                    return 'DL Number cannot be more than 20 characters.';
                if (mode === 'submit' && this.dlNo?.length !== 20)
                    return 'DL Number must be 20 characters long.';
                break;
            case 'dlExpiryDate':
                if (mode === 'submit' && new Date(this.dlExpiryDate) <= new Date()) {
                    return 'DL Expiry Date must be in the future.';
                }
                break;
            case 'validTillDate':
                if (mode === 'submit' && new Date(this.validTillDate) <= new Date()) {
                    return 'Valid Till Date must be in the future.';
                }
                break;

            case 'panNumber':
                if (this.panNumber?.length > 10)
                    return 'PAN Number cannot be more than 10 characters.';
                if (mode === 'submit') {
                    if (this.panNumber?.length !== 10)
                        return 'PAN Number must be 10 characters long (e.g. ABCDE1234F).';
                    const panRegex = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;
                    if (!panRegex.test(this.panNumber))
                        return 'Invalid PAN format (e.g. ABCDE1234F).';
                }
                break;
            case 'gstNumber':
                if (this.gstNumber?.length > 15)
                    return 'GST Number cannot be more than 15 characters.';
                if (mode === 'submit') {
                    if (this.gstNumber?.length !== 15)
                        return 'GST Number must be 15 characters long (e.g. 27ABCDE1234F1Z5).';
                    const gstRegex = /^\d{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
                    if (!gstRegex.test(this.gstNumber))
                        return 'Invalid GST format (e.g. 27ABCDE1234F1Z5).';
                }
                break;

            case 'mobile':
                if (this.mobile?.length > 10)
                    return 'Mobile Number cannot exceed 10 digits.';
                if (mode === 'submit' && !/^\d{10}$/.test(this.mobile))
                    return 'Mobile Number must be a valid 10-digit number.';
                break;
            case 'pin':
                if (this.pin?.length > 6)
                    return 'PIN Code cannot exceed 6 digits.';
                if (mode === 'submit' && !/^\d{6}$/.test(this.pin))
                    return 'PIN Code must be a valid 6-digit number.';
                break;
            case 'shipPin':
                if (this.shipPin?.length > 6)
                    return 'Shipping PIN Code cannot exceed 6 digits.';
                if (mode === 'submit' && !/^\d{6}$/.test(this.shipPin))
                    return 'Shipping PIN Code must be a valid 6-digit number.';
                break;
            case 'accountNumber':
                if (this.accountNumber?.length > 18)
                    return 'Bank Account Number cannot exceed 18 digits.';
                if (mode === 'submit' && !/^\d{9,18}$/.test(this.accountNumber))
                    return 'Bank Account Number must be between 9 to 18 digits.';
                break;
            case 'ifsc':
                if (this.ifsc?.length > 11)
                    return 'IFSC Code cannot exceed 11 characters.';
                if (mode === 'submit' && !/^[A-Z]{4}0[A-Z0-9]{6}$/.test(this.ifsc))
                    return 'IFSC Code must be 11 characters and valid format (e.g., ABCD0123456).';
                break;
            case 'creditDates':
                if (this.creditStartDate && this.creditEndDate && this.creditEndDate < this.creditStartDate)
                    return 'End Date cannot be earlier than Start Date.';
                break;
            case 'city':
                if (this.city && !/^[a-zA-Z\s]+$/.test(this.city)) {
                    return 'City should only contain letters and spaces.';
                }
                break;
            case 'shipCity':
                if (this.shipCity && !/^[a-zA-Z\s]+$/.test(this.shipCity)) {
                    return 'Shipping City should only contain letters and spaces.';
                }
                break;
        }
        return null;
    }

    handleSubmit() {
        const onboardingData = {
            distributorName: this.distributorName,
            distributorId: this.distributorId,
            selectedDistributorType: this.selectedDistributorType,
            selectedSuperDistributor: this.selectedSuperDistributor,
            selectedDistributor: this.selectedDistributor,
            address: this.address,
            city: this.city,
            selectedState: this.selectedState,
            pin: this.pin,
            shipAddress: this.shipAddress,
            shipPin: this.shipPin,
            shipCity: this.shipCity,
            shipState: this.selectedShipState,
            firstName: this.firstName,
            lastName: this.lastName,
            email: this.email,
            mobile: this.mobile,
            accountNumber: this.accountNumber,
            paymentTerm: this.paymentTerm,
            ifsc: this.ifsc,
            bankName: this.bankName,
            panNumber: this.panNumber,
            gstNumber: this.gstNumber,
            selectedPriceBook: this.selectedPriceBook,
            creditLimit: this.creditLimit,
            creditStartDate: this.creditStartDate,
            creditEndDate: this.creditEndDate,
            salesRep: this.salesRep,
            selectedHospitals: this.selectedHospitals,
            zydusMapping: this.zydusMapping,
            drugLicenceNumber: this.drugLicenceNumber,
            validTillDate: this.validTillDate,
            uploadedFiles: this.documentUploads
        };

        this.isLoading = true;

        submitDistributorForApproval({ onboardingData: JSON.stringify(onboardingData) })
            .then(result => {
                if (result == 'Distributor already exists for the provided GST and PIN code!') {
                    this.showToast('Warning', result, 'warning');
                } else {
                    this.showToast('Success', result, 'success');
                    this.closeDistributorOnboarding();
                }
            })
            .catch(error => {
                this.showToast('Error', 'There was an error submitting the distributor: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSubmitDistributorForApproval() {
        const allValid = [...this.template.querySelectorAll(
            'lightning-input, lightning-combobox, lightning-textarea'
        )].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        const allFilesUploaded = this.documentUploads.every(doc => doc.confirmed && doc.fileData);

        const fieldsToValidate = [
            'drugLicenceNumber', 'panNumber', 'gstNumber',
            'mobile', 'pin', 'accountNumber', 'ifsc', 'creditDates'
        ];

        for (const field of fieldsToValidate) {
            const msg = this.validateFields(field, 'submit');
            if (msg) {
                this.showToast('Warning', msg, 'warning');
                return;
            }
        }

        if (this.selectedDistributorType !== 'Super Distributor' &&
            (this.selectedDistributor == '' && this.selectedSuperDistributor == '')) {
            this.showToast('Warning', 'Please select Distributor or Super Distributor', 'warning');
            return;
        }

        if (!this.zydusMapping) {
            this.showToast('Warning', 'Please select a Zydus Mapping.', 'warning');
            return;
        }

        if (allValid && allFilesUploaded) {
            this.handleSubmit();
        } else {
            console.warn('Please fill out all required fields and upload all required documents.');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please fill out all required fields and upload all required documents.',
                    variant: 'error',
                })
            );
        }
    }


    closeDistributorOnboarding() {
        this.isShippingSame = false;
        this.shipAddress = '';
        this.shippingAddress = '';
        this.selectedShipState = '';
        this.shipCity = '';
        this.shipPin = '';
        this.isLoading = false;
        this.isDistributorSelected = false;
        this.distributorName = '';
        this.distributorId = '';
        this.selectedOnboardingType = '';
        this.selectedDistributorType = '';
        this.selectedSuperDistributor = '';
        this.selectedSubDistributor = '';
        this.address = '';
        this.city = '';
        this.selectedState = '';
        this.pin = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.mobile = '';
        this.accountNumber = '';
        this.ifsc = '';
        this.bankName = '';
        this.panNumber = '';
        this.gstNumber = '';
        this.selectedPriceBook = '';
        this.creditLimit = '';
        this.creditStartDate = null;
        this.creditEndDate = null;
        this.salesRep = '';
        this.selectedHospitals = [];
        this.zydusMapping = '';
        this.drugLicenceNumber = '';
        this.validTillDate = null;
        this.documentUploads = [];
    }

    handleHospNameChange(event) {
        this.hospitalName = event.detail.value;
    }
    handleHospRegNoChange(event) {
        this.hospRegistrationNumber = event.detail.value;
    }
    handlehospGroupChange(event) {
        this.hospGroup = event.detail.value;
    }
    handleStateChangeForHosp(event) {
        this.selectedState = event.detail.value;
        this.updateHospitalId();
    }

    handleBillingAddressChange(event) {
        this.billingAddress = event.detail.value;
    }

    fiveDigitHospitalNumber;

    @wire(getLatestHospitalId)
    wiredLatestHospitalId({ error, data }) {
        if (data) {
            console.log('data', data);
            const match = data.match(/\d+$/);
            if (match) {
                this.fiveDigitHospitalNumber = match[0].padStart(5, '0');
            }
        } else if (error) {
            console.error('Error fetching latest Hospital ID:', error);
        }
    }

    updateHospitalId() {
        if (this.selectedState && this.fiveDigitHospitalNumber !== undefined) {

            const stateObj = this.states.find(state => state.label === this.selectedState);

            const stateCode = stateObj ? stateObj.value : '';

            const hospitalCode = 'H';

            const nextNumber = String(parseInt(this.fiveDigitHospitalNumber, 10) + 1).padStart(5, '0');

            this.hospitalId = stateCode
                ? `${stateCode}${hospitalCode}${nextNumber}`
                : '';
        } else {
            this.distributorId = '';
        }
    }
    handleCCEmailChange(event) {
        this.ccEmail = event.detail.value;
    }
    handleShipTitleChange(event) {
        this.shipTitle = event.detail.value;
    }
    handleShippingAddressChange(event) {
        this.shippingAddress = event.detail.value;
    }
    handleShipCityChange(event) {
        this.shipCity = event.detail.value;
        const msg = this.validateFields('shipCity', 'submit');
        const inputCmp = this.template.querySelector('[data-id="shipCityInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }
    handleShipStateChange(event) {
        this.selectedShipState = event.detail.value;
    }
    handleShipPinChange(event) {
        this.shipPin = event.detail.value;
        const msg = this.validateFields('shipPin', 'submit');
        const inputCmp = this.template.querySelector('[data-id="shipPinInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleShippingSameAsBilling(event) {
        this.isShippingSame = event.detail.checked;
        if (this.isShippingSame) {
            this.shipAddress = this.address;
            this.shippingAddress = this.billingAddress;
            this.selectedShipState = this.selectedState;
            this.shipCity = this.city;
            this.shipPin = this.pin;
        } else {
            this.shipAddress = '';
            this.shippingAddress = '';
            this.selectedShipState = '';
            this.shipCity = '';
            this.shipPin = '';
        }
    }

    handleDLChange(event) {
        this.dlNo = event.detail.value;
        const msg = this.validateFields('dlNo', 'submit');
        const inputCmp = this.template.querySelector('[data-id="dlInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }

    handleDoctorNameChange(event) {
        this.doctorName = event.detail.value;
    }
    handlePaymentTermChange(event) {
        this.paymentTerm = event.detail.value;
    }
    handleInvoiceCommentChange(event) {
        this.invoiceComment = event.detail.value;
    }

    handleDlExpiryDateChange(event) {
        this.dlExpiryDate = event.detail.value;
        const msg = this.validateFields('dlExpiryDate', 'submit');
        const inputCmp = this.template.querySelector('[data-id="dlExpiryDateInput"]');
        inputCmp.setCustomValidity(msg || '');
        inputCmp.reportValidity();
    }
    handlehospGroupChange(event) {
        this.hospGroup = event.detail.value;
    }

    @track roleHOB = '';
    @track superDistributorOptionsHOB = [];
    @track distributorOptionsHOB = [];
    @track subDistributorOptionsHOB = [];

    @track selectedSuperDistributorHOB = null;
    @track selectedDistributorHOB = null;
    @track selectedSubDistributorHOB = null;

    connectedCallback() {
        this.loadUserHierarchy();
    }

    loadUserHierarchy() {
        fetchUserDistributorHierarchy({ userId: USER_ID }) // Replace USER_ID with actual logic
            .then(result => {
                this.roleHOB = result.role || '';

                if (this.roleHOB === 'System Admin') {
                    this.superDistributorOptionsHOB = result.superDistributorOptions || [];
                    this.resetSelections();
                } else {
                    if (result.superDistributor) {
                        this.selectedSuperDistributorHOB = {
                            label: result.superDistributor.Name,
                            value: result.superDistributor.Id
                        };
                    }
                    if (result.distributor) {
                        this.selectedDistributorHOB = {
                            label: result.distributor.Name,
                            value: result.distributor.Id
                        };
                    }
                    if (result.subDistributor) {
                        this.selectedSubDistributorHOB = {
                            label: result.subDistributor.Name,
                            value: result.subDistributor.Id
                        };
                    }

                    this.distributorOptionsHOB = result.distributorOptions || [];
                    this.subDistributorOptionsHOB = result.subDistributorOptions || [];
                }
            })
            .catch(error => {
                console.error('Error loading user hierarchy:', error);
            });
    }

    resetSelections() {
        this.selectedSuperDistributorHOB = null;
        this.selectedDistributorHOB = null;
        this.selectedSubDistributorHOB = null;
        this.distributorOptionsHOB = [];
        this.subDistributorOptionsHOB = [];
    }

    // ✅ Role-based UI access
    get isSuperDistributorDisabledHOB() {
        return this.roleHOB !== 'System Admin';
    }

    get isDistributorDisabledHOB() {
        return !['System Admin', 'Super Distributor', 'Distributor'].includes(this.roleHOB);
    }

    get isSubDistributorDisabledHOB() {
        return !['System Admin', 'Super Distributor', 'Distributor', 'Sub Distributor'].includes(this.roleHOB);
    }

    // ✅ Options and Values for Comboboxes
    get HOBsuperDistributorOptionsHOB() {
        return this.superDistributorOptionsHOB;
    }

    get HOBdistributorOptionsHOB() {
        return this.distributorOptionsHOB;
    }

    get HOBsubDistributorOptionsHOB() {
        return this.subDistributorOptionsHOB;
    }

    get HOBselectedSuperDistributorHOBValue() {
        return this.selectedSuperDistributorHOB?.value || null;
    }

    get HOBselectedDistributorHOBValue() {
        return this.selectedDistributorHOB?.value || null;
    }

    get HOBselectedSubDistributorHOBValue() {
        return this.selectedSubDistributorHOB?.value || null;
    }

    get HOBselectedSuperDistributorHOB() {
        return this.selectedSuperDistributorHOB;
    }

    get HOBselectedDistributorHOB() {
        return this.selectedDistributorHOB;
    }

    get HOBselectedSubDistributorHOB() {
        return this.selectedSubDistributorHOB;
    }

    // ✅ Change Handlers
    HOBhandleSuperDistributorChange(event) {
        const selectedValue = event.detail.value;
        this.selectedSuperDistributorHOB = this.superDistributorOptionsHOB.find(opt => opt.value === selectedValue) || null;
        this.selectedDistributorHOB = null;
        this.selectedSubDistributorHOB = null;
        this.distributorOptionsHOB = [];
        this.subDistributorOptionsHOB = [];

        if (this.selectedSuperDistributorHOB) {
            getDistributorsBySuper({ superDistributorId: selectedValue })
                .then(distributors => {
                    this.distributorOptionsHOB = distributors;
                })
                .catch(error => {
                    console.error('Error fetching distributors:', error);
                    this.distributorOptionsHOB = [];
                });
        }
    }

    HOBhandleDistributorChange(event) {
        const selectedValue = event.detail.value;
        this.selectedDistributorHOB = this.distributorOptionsHOB.find(opt => opt.value === selectedValue) || null;
        this.selectedSubDistributorHOB = null;
        this.subDistributorOptionsHOB = [];

        if (this.selectedDistributorHOB) {
            getSubDistributorsByDistributor({ distributorId: selectedValue })
                .then(subDistributors => {
                    this.subDistributorOptionsHOB = subDistributors;
                })
                .catch(error => {
                    console.error('Error fetching sub distributors:', error);
                    this.subDistributorOptionsHOB = [];
                });
        }
    }

    HOBhandleSubDistributorChange(event) {
        const selectedValue = event.detail.value;
        this.selectedSubDistributorHOB = this.subDistributorOptionsHOB.find(opt => opt.value === selectedValue) || null;
    }

    // ✅ Pill Removal Handler
    HOBhandleRemovePill(event) {
        const pillName = event.target.name;

        switch (pillName) {
            case 'super':
                this.resetSelections();
                break;
            case 'distributor':
                this.selectedDistributorHOB = null;
                this.selectedSubDistributorHOB = null;
                this.subDistributorOptionsHOB = [];
                break;
            case 'subDistributor':
                this.selectedSubDistributorHOB = null;
                break;
        }
    }
    get selectedCommentOptionsString() {
        return this.commentOptionSelected.map(option => option.value).join(',');
    }

    handleCommentOptionsChange(event) {
        const selectedValue = event.detail.value;

        const selectedOption = this.commentOptions.find(
            option => option.value === selectedValue
        );

        if (selectedOption && !this.commentOptionSelected.some(option => option.value === selectedOption.value)) {
            this.commentOptionSelected = [...this.commentOptionSelected, selectedOption];
        }
    }

    handleCommentOptionsRemove(event) {
        const valueToRemove = event.target.dataset.value;
        this.commentOptionSelected = this.commentOptionSelected.filter(option => option.value !== valueToRemove);
    }
    handlephyziiIdChange(event) {
        this.phyziiId = event.target.value;
    }
    handleSubmitHospitalForApproval() {
        const allValid = [...this.template.querySelectorAll(
            'lightning-input, lightning-textarea, lightning-combobox'
        )].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (!allValid) {
            this.showToast('Warning', 'Please fix validation errors before submitting.', 'warning');
            return;
        }

        const hasSelectedPartner = this.selectedSuperDistributorHOB || this.selectedDistributorHOB || this.selectedSubDistributorHOB;

        if (!hasSelectedPartner) {
            this.showToast('Warning', 'Please select at least one Channel Partner before submitting.', 'warning');
            return;
        }

const hospitalRecordPayload = {
    hospitalName: this.hospitalName,
    hospRegistrationNumber: this.hospRegistrationNumber,
    hospGroup: this.hospGroup,
    firstName: this.firstName,
    lastName: this.lastName,
    email: this.email,
    mobile: this.mobile,
    ccEmail: this.ccEmail,
    billingAddress: this.billingAddress,
    city: this.city,
    selectedPriceBook: this.selectedPriceBook,
    selectedState: this.selectedState,
    pin: this.pin,
    shippingAddress: this.shippingAddress,
    shipCity: this.shipCity,
    selectedShipState: this.selectedShipState,
    shipPin: this.shipPin,
    shipTitle: this.shipTitle,
    selectedSuperDistributor: this.selectedSuperDistributorHOB?.value || null,
    selectedDistributor: this.selectedDistributorHOB?.value || null,
    selectedSubDistributor: this.selectedSubDistributorHOB?.value || null,
    panNumber: this.panNumber,
    gstNumber: this.gstNumber,
    dlNo: this.dlNo,
    dlExpiryDate: this.dlExpiryDate,
    doctorName: this.doctorName,
    paymentTerm: this.paymentTerm,
    invoiceComment: this.invoiceComment,
    hospitalId: this.hospitalId,
    phyziiId: this.phyziiId,
    selectedProducts: this.selectedProducts,
    commentOptionSelected: this.selectedCommentOptionsString
};


        console.log('Hospital Record Payload:', JSON.stringify(hospitalRecordPayload));
        this.isLoading = true;

        createHospitalRecord({ onboardingData: JSON.stringify(hospitalRecordPayload) })
            .then(resultMessage => {
                if (resultMessage === 'Hospital already exists for the provided GST and PIN code!') {
                    this.showToast('Warning', resultMessage, 'warning');
                } else {
                    this.showToast('Success', resultMessage, 'success');
                    this.closeHospitalOnboarding();
                }
            })
            .catch(error => {
                this.showToast('Error', `There was an error submitting the hospital: ${error.body.message}`, 'error');
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeHospitalOnboarding() {
        this.isLoading = false;
        this.isHospitalSelected = false;
        this.selectedOnboardingType = '';
        this.hospitalName = '';
        this.hospRegistrationNumber = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.mobile = '';
        this.city = '';
        this.selectedState = '';
        this.pin = '';
        this.hospitalId = '';
        this.billingAddress = '';
        this.dlNo = '';
        this.selectedShipState = '';
        this.shipPin = '';
        this.shipCity = '';
        this.shipTitle = '';
        this.shippingAddress = '';
        this.panNumber = '';
        this.gstNumber = '';
        this.doctorName = '';
        this.paymentTerm = '';
        this.invoiceComment = '';
        this.dlExpiryDate = '';
        this.ccEmail = '';
        this.hospGroup = '';
        this.mappingSelectedChannelPartnerType = '';
        this.mappingSelectedChannelPartner = '';
        this.mappingChannelPartnerOptions = [];
        this.mappingSelectedSuperDistributorId = '';
        this.mappingSelectedDistributorId = '';
        this.mappingSelectedSubDistributorId = '';
        this.salesRep = '';
        this.selectedPriceBook = '';
        this.selectedProucts = [];
        this.commentOptionSelected = [];
        this.phyziiId = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}