import { LightningElement, track, wire } from 'lwc';
import getUserAccountsAndHospitals from '@salesforce/apex/InvoiceCreationController.getUserAccountsAndHospitals';
import getWarehouseProductLineItems from '@salesforce/apex/InvoiceCreationController.getWarehouseProductLineItems';
import getWarehouseProductLineItemsBySerialNumber from '@salesforce/apex/InvoiceCreationController.getWarehouseProductLineItemsBySerialNumber';
import saveInvoice from '@salesforce/apex/InvoiceCreationController.saveInvoice';
import existingDoctor from '@salesforce/apex/InvoiceCreationController.existingDoctor';
import RelatedDCToHosp from '@salesforce/apex/InvoiceCreationController.RelatedDCToHosp';
import getScheme from '@salesforce/apex/InvoiceCreationController.getScheme';
import getCreditNoteOptions from '@salesforce/apex/InvoiceCreationController.getCreditNoteOptions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSubChannelPartnerOptions from '@salesforce/apex/InvoiceCreationController.getSubChannelPartnerOptions';
import getDeliveryChallanForChannelPartner from '@salesforce/apex/InvoiceCreationController.getDeliveryChallanForChannelPartner';
import getInvoices from '@salesforce/apex/InvoiceCreationController.getInvoices';
import getChannelPartnerLineItems from '@salesforce/apex/InvoiceCreationController.getChannelPartnerLineItems';
import getChannelPartnerLineItemsBySerialNumber from '@salesforce/apex/InvoiceCreationController.getChannelPartnerLineItemsBySerialNumber';
import saveInvoiceCP from '@salesforce/apex/InvoiceCreationController.saveInvoiceCP';
import getPaymentModePicklistValues from '@salesforce/apex/InvoiceCreationController.getPaymentModePicklistValues';
import existingCATHNumber from '@salesforce/apex/InvoiceCreationController.existingCATHNumber';
import { NavigationMixin } from 'lightning/navigation';
const SERIAL_NUMBER_LENGTH = 15;
export default class InvoiceCreation extends NavigationMixin(LightningElement) {
    @track accountOptions = [];
    @track deliveryChallanOptions = [];
    @track hospitalOptions = [];
    @track selectedAccountId;
    @track selectedHospitalId;
    @track warehouseLineItems = [];
    @track selectedLineItemIds = [];
    @track showComponent = true;
    @track errorMessage = '';
    @track deliveryChallanId;
    @track invoiceTypeOptions = [];
    @track selectedInvoiceType;
    @track selectedAccountDetails = {};
    @track isLoaded = false;
    @track implantDate = '';
    @track ipNumber = '';
    @track cathNumber = '';
    @track comment = '';
    @track creditNote = '';
    @track uploadedFileIds = [];
    @track schemeOptions = [];
    @track creditNoteOptions = [];
    @track doctorInput = '';
    @track suggestions = [];
    @track showDropdown = false;
    timeoutId;
    @track selectedScheme = null;
    @track creditNote;
    @track uploadedFiles;
    @track patient = { firstName: '', lastName: '', age: '', gender: '' };
    @track selectedInvoiceCreationType = false;
    @track isChannelPartnerMode = false;
    @track selectedChannelPartner = '';
    @track channelPartnerOptions = [];
    @track selectedDeliveryChallan = '';
    @track channelPartnerDeliveryChallanOptions = [];
    @track selectedInvoice = '';
    @track invoiceOptions = [];
    @track implantDateCP;
    @track ipNumberCP;
    @track cathNumberCP;
    @track patientFirstNameCP;
    @track patientLastNameCP;
    @track patientAgeCP;
    @track patientRegisterNumberCP;
    @track patientGenderCP;
    @track doctorInputCP;
    @track warehouseLineItemOptionsCP = [];
    @track paymentMode;
    @track paymentModeOptions = [];
    @track showCathDropdown = false;
    @track cathSuggestions = [];
    @track selectedSchemeName = '';
    @track isHospitalMode = false;
    @track invoiceLable = 'Create Invoice';
    @track invoiceLableCP = 'Create Invoice';
    @track showMainRadioBtns = true;
    @track selectedOption;
    @track showInvoiceFromDC = false;
    @track showInvoiceByScan = false;
    @track patientFirstName;
    @track patientLastName;
    @track patientAge;
    @track patientRegisterNumber;
    @track cathNumber;
    @track ipNumber;
    @track doctorName;
    @track showPatientDetail = false;
    @track patientGender;
    @track implantDate;
    @track hospitalAray = [];
    @track distributorList = [];
    @track selectedHospital;
    disableCreateInvoiceBtn;
    showBackBtn = false;
    blurTimeout
    genderOptions = [
        { label: 'Male', value: 'Male' },
        { label: 'Female', value: 'Female' }
    ];
    invoiceCreationOptions = [
        { label: 'Hospital Invoice', value: 'hospital' },
        { label: 'Channel Partner Invoice', value: 'channelPartner' }
    ]
    radioOptions = [
        { label: 'Create from Delivery Challan', value: 'createFromDC' },
        { label: 'Create by Item Scan', value: 'createByItemScan' }
    ]

    handleRadioChange(event) {
        this.selectedInvoiceCreationType = false;
        this.selectedOption = event.detail.value;
        this.isHospitalMode = false;
        this.isChannelPartnerMode = false;
        if (this.selectedOption === 'createFromDC') {
            this.showInvoiceFromDC = true;
            this.showMainRadioBtns = false;
        } else if (this.selectedOption === 'createByItemScan') {
            this.showInvoiceByScan = true;
            this.showMainRadioBtns = false;
        }
        this.showBackBtn = true;
    }

    handleBack() {
        this.selectedOption = '';
        this.selectedChannelPartner='';
        this.deliveryChallanId='';
        this.deliveryChallanOptions=[];
        this.selectedHospital='';
        this.selectedHospitalId='';
        this.channelPartnerDeliveryChallanOptions=[];
        this.warehouseLineItemOptionsCP=[];
        this.warehouseLineItem=[];
        this.selectedChannelPartnerName='';
        this.showMainRadioBtns = true;
        this.showInvoiceFromDC = false;
        this.showInvoiceByScan = false;
        this.showBackBtn = false;
        this.resetFields()
    }

    resetFields() {
        this.selectedInvoice = '';
        this.selectedDeliveryChallan = '';
        this.selectedChannelPartner = '';
        this.warehouseLineItemOptions = [];
        this.warehouseLineItems = [];
        this.warehouseLineItemOptionsCP = [];
    }


    handleInvoiceCreationTypeChange(event) {

        this.selectedInvoiceCreationType = event.detail.value;
        this.isHospitalMode = this.selectedInvoiceCreationType === 'hospital';
        this.isChannelPartnerMode = this.selectedInvoiceCreationType === 'channelPartner';
        setTimeout(() => {
            this.warehouseLineItemOptionsCP = [];
            this.warehouseLineItemOptions = [];
        }, 0);
    }

    @wire(getScheme)
    wiredSchemes({ error, data }) {
        if (data) {
            this.schemeOptions = data.map(scheme => ({
                label: scheme.Name,
                value: scheme.Id,
                discount: scheme.Discount_Value__c
            }));
        } else if (error) {
            console.error('Error fetching schemes', error);
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
                const firstAccount = accountList[0];
                if (firstAccount.Validity_of_Drug_Licence__c) {
                    const validityDate = new Date(firstAccount.Validity_of_Drug_Licence__c);
                    const today = new Date();
                    today.setHours(0, 0, 0, 0);

                    if (validityDate < today) {
                        this.showComponent = false;
                        this.errorMessage = 'Your drug license has expired. Please renew or update it to proceed.';
                        return;
                    }
                }

                this.selectedAccountId = firstAccount.Id;

                this.selectedAccountDetails = {
                    name: firstAccount.Name || 'N/A',
                    phone: firstAccount.Mobile_Number__c || 'N/A',
                    pan: firstAccount.PAN_Number__c || 'N/A',
                    email: firstAccount.Contact_Person_Email__c || 'N/A',
                    address: `${firstAccount.Address__c}, ${firstAccount.City__c}, ${firstAccount.State__c}, ${firstAccount.Account_Pin_Code__c}` || 'N/A',
                    billingStreet: firstAccount.Address__c || 'N/A',
                    billingCity: firstAccount.City__c || 'N/A',
                    billingState: firstAccount.State__c || 'N/A',
                    billingPostalCode: firstAccount.Pin_Code__c || 'N/A'
                };

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

            this.hospitalAray = Object.entries(data.hospitals).map(([id, name]) => ({
                label: name,
                value: id
            }));
        } else if (error) {
            this.showComponent = false;
            this.errorMessage = 'Error loading accounts and hospitals.';
            console.error('Error loading accounts and hospitals', error);
        }

        this.isLoaded = false;
    }

    get showHospitalDropdown() {
        return this.hospitalOptions.length > 0;
    }
    handleHospFocus() {
        this.hospitalOptions = [...this.hospitalAray];
    }
    handleHospBlur() {
        setTimeout(() => {
            this.hospitalOptions = [];
        }, 300);
    }
    handleHospitalInput(event) {
        const hosp = event.target.value;
        this.hospitalOptions = this.hospitalAray.filter(item =>
            item.label.toLowerCase().includes(hosp.toLowerCase())
        );
    }

    handleInvoiceTypeChange(event) {
        this.selectedInvoiceType = event.detail.value;
    }
    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value;
    }

    handleHospitalChange(event) {
        this.selectedHospital = event.currentTarget.dataset.value;
        this.selectedHospitalId = event.currentTarget.dataset.id;

        console.log('this.selectedHospital:', this.selectedHospital);
        console.log('this.selectedHospitalId:', this.selectedHospitalId);

        this.selectedLineItemIds = [];
        this.warehouseLineItems = [];
        this.hospitalOptions = [];
        this.fetchDeliveryChallan();
    }

    fetchDeliveryChallan() {
        RelatedDCToHosp({ HospId: this.selectedHospitalId })
            .then(result => {
                console.log('result: ', result);
                this.deliveryChallanOptions = Object.entries(result.relatedDCs || {}).map(([key, value]) => ({
                    label: value,
                    value: key
                }));
            })
            .catch(error => {
                console.error('Error fetching delivery challans:', error);
                this.showComponent = false;
                this.errorMessage = 'Failed to load delivery challans. Please try again.';
            });
    }

    fetchWarehouseItems() {
        getWarehouseProductLineItems({ hospitalId: this.selectedHospitalId, deliveryChallanId: this.deliveryChallanId })
            .then(wrapperList => {
                console.log('Wrappered WPL Items:', wrapperList);
                this.warehouseLineItems = wrapperList.map(wrapper => ({
                    ...wrapper,
                    isSelected: false,
                    selectedScheme: null,
                    selectedSchemeName: null
                }));
            })
            .catch(error => {
                console.error('Error fetching warehouse product line items', error);
            });
    }

    handleDeliveryChallanChange(event) {
        this.deliveryChallanId = event.detail.value;
        this.fetchCreditNotes();
        this.fetchWarehouseItems();
    }

    get disableCN() {
        return !this.deliveryChallanId;
    }

    fetchCreditNotes() {
        getCreditNoteOptions({ DCId: this.deliveryChallanId })
            .then((result) => {
                console.log('Result:', result);
                this.creditNoteOptions = result
            })
            .catch((error) => {
                console.error('Error fetching credit notes:', error);
            });
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.uploadedFileIds = uploadedFiles.map(file => file.documentId);
        this.uploadedFiles = uploadedFiles.map(file => ({
            name: file.name,
            documentId: file.documentId
        }));
    }

    handleDeleteFile(event) {
        const fileIdToDelete = event.currentTarget.dataset.id;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== fileIdToDelete);
    }

    handleInputChange(event) {
        const field = event.target.name;
        const section = event.target.dataset.section;

        if (section === 'patient') {
            this.patient[field] = event.target.value;
        } else {
            switch (field) {
                case 'implantDate':
                    this.implantDate = event.target.value;
                    break;
                case 'ipNumber':
                    this.ipNumber = event.target.value;
                    break;
                case 'cathNumber':
                    this.cathNumber = event.target.value;
                    this.getMatchingCathNumbers(this.cathNumber);
                    break;
                case 'comment':
                    this.comment = event.target.value;
                    break;
                case 'creditNote':
                    this.creditNote = event.target.value;
                    break;
                case 'Doctor Name':
                    this.doctorInput = event.target.value;
                    clearTimeout(this.timeoutId);
                    this.timeoutId = setTimeout(() => {
                        this.fetchDoctorSuggestions(this.doctorInput);
                    }, 200);
                    this.showDropdown = true;
                    break;
            }
        }
    }

    showCathSuggestions() {
        this.getMatchingCathNumbers('');
        if (this.cathSuggestions.length > 0) {
            this.showCathDropdown = true;
        }
    }
    hideCathDropDownWithDelay() {
        setTimeout(() => {
            this.showCathDropdown = false;
        }, 100);
    }

    handleCathSuggestionClick(event) {
        try {
            const selectedCath = event.currentTarget.dataset.cath;
            this.cathNumber = selectedCath;
            this.showCathDropdown = false;
        } catch (err) {
            console.error('Error in handleCathSuggestionClick:', err);
        }
    }

    getMatchingCathNumbers(input) {

        existingCATHNumber({ keyword: input })
            .then(result => {
                // Ensure result is an array
                if (Array.isArray(result)) {
                    this.cathSuggestions = result;
                    this.showCathDropdown = result.length > 0;
                } else {
                    console.warn('Unexpected result from existingCATHNumber:', result);
                    this.cathSuggestions = [];
                    this.showCathDropdown = false;
                }
            })
            .catch(error => {
                console.error('Error fetching CATH numbers:', error);
                this.cathSuggestions = [];
                this.showCathDropdown = false;
            });
    }


    handleSuggestionClick(event) {
        const selected = event.currentTarget.dataset.doctor;
        this.doctorInput = selected;
        this.showDropdown = false;
    }

    showSuggestions() {
        this.fetchDoctorSuggestions('');
        if (this.suggestions.length > 0) {
            this.showDropdown = true;
        }
    }


    hideSuggestionsWithDelay() {
        setTimeout(() => {
            this.showDropdown = false;
        }, 100);
    }

    fetchDoctorSuggestions(keyword) {
        existingDoctor({ keyword: keyword })
            .then(result => {
                this.suggestions = result;
            })
            .catch(error => {
                console.error('Error fetching doctor suggestions:', error);
                this.suggestions = [];
            });
    }

    handleSaveInvoice() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')]
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

        const selectedLineItems = this.warehouseLineItems
            .filter(item => item.isSelected)
            .map(item => ({
                id: item.record.Id,
                SGST: item.discountedSGST !== undefined ? item.discountedSGST : item.cgst || 0,
                CGST: item.discountedCGST !== undefined ? item.discountedCGST : item.sgst || 0,
                IGST: item.discountedIGST !== undefined ? item.discountedIGST : item.igst || 0,
                dcLineItem: item.record?.Delivery_Challan_Line_Item__c || null,
                dc: item.record?.Delivery_Challan_Line_Item__r?.Delivery_Challan__c || null,
                netAmount: (item.discountedNetAmount !== undefined ? item.discountedNetAmount : item.netAmount) - (item.record?.Delivery_Challan_Line_Item__r?.Zydus_Price_Book_Entry__r?.Bill_Discount_Amount__c || 0),
                scheme: item.selectedSchemeName,
                billDiscountAmount: item.record?.Delivery_Challan_Line_Item__r?.Zydus_Price_Book_Entry__r?.Bill_Discount_Amount__c || 0
            }));

        if (selectedLineItems.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select at least one product.',
                variant: 'error'
            }));
            return;
        }

        console.log('selectedLineItems', JSON.stringify(selectedLineItems));

        const invoiceData = {
            patient: this.patient,
            doctor: {
                name: this.doctorInput,
                ipNumber: this.ipNumber,
                cathNumber: this.cathNumber,
                implantDate: this.implantDate,
                comment: this.comment
            },
            invoiceType: this.selectedInvoiceType,
            hospitalId: this.selectedHospitalId,
            accountId: this.selectedAccountId,
            lineItemIds: selectedLineItems,
            uploadedFileIds: this.uploadedFileIds,
            deliveryChallanId: this.deliveryChallanId,
            creditNote: this.creditNote
        };

        this.invoiceLable = 'Creating Invoice...';
        this.disableCreateInvoiceBtn = true;
        console.log('invoiceData', invoiceData);

        saveInvoice({ invoiceData: JSON.stringify(invoiceData) })
            .then((result) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Invoice saved successfully',
                    variant: 'success'
                }));
                this.isHospitalMode = false;
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: 'Invoice__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                console.error('Error saving invoice:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to save invoice. ' + (error.body?.message || ''),
                    variant: 'error'
                }));
            }).finally(() => {
                this.invoiceLable = 'Create Invoice';
                this.disableCreateInvoiceBtn = false;
            });
    }

    get disableDC() {
        return !this.selectedHospitalId;
    }


    get warehouseLineItemOptions() {
        return this.warehouseLineItems.map(item => {
            const rec = item.record;
            const dcLineItem = rec.Delivery_Challan_Line_Item__r || {};
            const pbEntry = dcLineItem.Zydus_Price_Book_Entry__r || {};

            const unitPrice = pbEntry.Unit_Price__c || 0;
            const billDiscount = pbEntry.Bill_Discount_Amount__c || 0;
            const baseNet = item.netAmount || 0;
            const creditNoteAmount = pbEntry.Credit_Note_Amount__c || 0;

            const SGST = item.discountedSGST != null ? item.discountedSGST : (item.cgst || 0);
            const CGST = item.discountedCGST != null ? item.discountedCGST : (item.sgst || 0);
            const IGST = item.discountedIGST != null ? item.discountedIGST : (item.igst || 0);

            const orignialTaxablePrice = unitPrice - billDiscount;
            const taxablePrice = item.discountedTaxablePrice != null
                ? item.discountedTaxablePrice
                : orignialTaxablePrice;
            const netAmount = (item.discountedNetAmount != null ? item.discountedNetAmount : baseNet)
                - billDiscount;

            return {
                Id: rec.Id,
                Serial_Number__c: rec.Serial_Number__c || 'Unnamed',
                Status__c: rec.Status__c,
                Condition__c: rec.Condition__c,
                Supplied_Date__c: rec.Supplied_Date__c,
                ProductName: rec.Warehouse__r?.Zydus_Product__r?.Name || 'Unknown',
                DC: dcLineItem.Name || 'Unknown',
                SGST,
                CGST,
                IGST,
                unitPrice,
                billDiscountAmount: billDiscount,
                creditNoteAmount: creditNoteAmount,
                orginalNetAmount: baseNet,
                orignialTaxablePrice,
                taxablePrice,
                netAmount,
                isSelected: item.isSelected || false,
                selectedScheme: item.selectedScheme || null,
                discount: item.discount || 0,
                selectedSchemeName: item.selectedSchemeName || null
            };
        });
    }

    get showNoMatch() {
        return this.suggestions.length === 0 && this.doctorInput.length > 0;
    }

    get selectedDoctor() {
        return this.doctorInput;
    }
    get isAllSelected() {
        return this.warehouseLineItems.length > 0 && this.warehouseLineItems.every(item => item.isSelected);
    }

    handleSelectAll(event) {
        const checked = event.target.checked;
        this.warehouseLineItems = this.warehouseLineItems.map(item => ({
            ...item,
            isSelected: checked
        }));
    }

    handleRowSelection(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;

        this.warehouseLineItems = this.warehouseLineItems.map(item => {
            if (item.record.Id === itemId) {
                return { ...item, isSelected: checked };
            }
            return item;
        });
    }

    handleSchemeChange(event) {
        this.selectedScheme = event.detail.value;
        const schemeObj = this.schemeOptions.find(s => s.value === this.selectedScheme);
        if (!schemeObj) return;

        this.selectedSchemeName = schemeObj.label;
        const discount = schemeObj.discount || 0;
        const factor = (100 - discount) / 100;

        this.warehouseLineItems = this.warehouseLineItems.map(item => {
            if (!item.isSelected) return item;

            const rec = item.record;
            const dcLineItem = rec.Delivery_Challan_Line_Item__r || {};
            const pbEntry = dcLineItem.Zydus_Price_Book_Entry__r || {};

            const unitPrice = pbEntry.Unit_Price__c || 0;
            const billDiscount = pbEntry.Bill_Discount_Amount__c || 0;

            const basic = unitPrice;
            const discountedBasic = basic * factor;

            const taxablePrice = factor * (unitPrice - billDiscount);
            const newCGST = +(taxablePrice * (item.cgst / basic) || 0).toFixed(2);
            const newSGST = +(taxablePrice * (item.sgst / basic) || 0).toFixed(2);
            const newIGST = +(taxablePrice * (item.igst / basic) || 0).toFixed(2);
            const newNet = +(taxablePrice + newCGST + newSGST + newIGST).toFixed(2);

            console.log('item.cgst:' + item.cgst);
            console.log('basic:' + basic);
            console.log('newCGST:' + newCGST);

            return {
                ...item,
                selectedScheme: this.selectedScheme,
                selectedSchemeName: this.selectedSchemeName,
                discountedCGST: newCGST,
                discountedSGST: newSGST,
                discountedIGST: newIGST,
                discountedNetAmount: newNet,
                discountedTaxablePrice: taxablePrice,
                discount
            };
        });
    }

    // CHANNER PARTNER INVOICE...
    @wire(getSubChannelPartnerOptions)
    wiredPartners({ data, error }) {
        if (data) {
            console.log('Channel Partners:', data);
            this.channelPartnerOptions = data.map(acc => ({
                label: acc.Name,
                value: acc.Id
            }));
        } else if (error) {
            console.error('Error fetching channel partners', error);
        }
    }
    get showDistributorDropdown() {
        return this.distributorList.length > 0;
    }

      handleDistFocus() {
        this.distributorList = [...this.channelPartnerOptions];
        this._isDropdownOpen = true; // Open the dropdown
    }

    handleDistBlur() {
        setTimeout(() => {
            this.distributorList = [];
            this._isDropdownOpen = false; // Close the dropdown
        }, 300);
    }

    get comboboxClasses() {
        let classes = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        if (this._isDropdownOpen) {
            classes += ' slds-is-open';
        }
        return classes;
    }


    @track selectedChannelPartnerName;
    handleChannelPartnerSelect(event) {
        this.selectedChannelPartnerName = event.currentTarget.dataset.value;
        this.selectedChannelPartner = event.currentTarget.dataset.id;

        getDeliveryChallanForChannelPartner({ Id: this.selectedChannelPartner })
            .then(result => {
                this.channelPartnerDeliveryChallanOptions = result.map(dc => ({
                    label: dc.Name,
                    value: dc.Id
                }));
            })
            .catch(error => {
                console.error('Error fetching delivery challans for channel partner:', error);
                this.showComponent = false;
                this.errorMessage = 'Failed to load delivery challans. Please try again.';
            });

        getCreditNoteOptions({ consigneeId: this.selectedChannelPartner })
            .then(result => {
                this.creditNoteOptions = result;
            })
            .catch(error => {
                console.error('Error fetching credit notes:', error);
            });
    }

    handleChannelPartnerChange(event) {
        const dist = event.target.value;
        this.distributorList = this.channelPartnerOptions.filter(item =>
            item.label.toLowerCase().includes(dist.toLowerCase())
        );
    }

    handleChannelPartnerDeliveryChallanChange(event) {
        this.warehouseLineItemOptionsCP = [];
        this.selectedDeliveryChallan = event.detail.value;

        getInvoices({ childAccountId: this.selectedChannelPartner, relavantDCId: this.selectedDeliveryChallan })
            .then(data => {
                console.log('Invoices:', data);
                this.invoiceOptions = data.map(inv => ({
                    label: inv.Name,
                    value: inv.Id
                }));
            })
            .catch(error => {
                console.error('Error fetching invoices', error);
                this.showComponent = false;
                this.errorMessage = 'Failed to load Invoices. Please try again after reload the page.';
            });
    }

    handleInvoiceChange(event) {
        this.warehouseLineItemOptionsCP = [];
        this.selectedInvoice = event.detail.value;
        this.fetchCPLineItems(this.selectedDeliveryChallan);
    }

    connectedCallback() {
        this.loadPaymentModes();
    }


    loadPaymentModes() {
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
    }

    fetchCPLineItems(dcId) {
        console.log('dcId', dcId);
        getChannelPartnerLineItems({ dcId: dcId, invoiceId: this.selectedInvoice })
            .then(result => {
                console.log('Line Items:', result);
                const filteredResult = result.filter(item => item.productName && item.productName.trim() !== '');
                if (filteredResult.length === 0) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'No line items found',
                            message: 'No items found associated with this delivery challan',
                            variant: 'warning'
                        })
                    )
                    return;
                }
                this.warehouseLineItemOptionsCP = filteredResult.map(item => {
                    const sgst = Number(item.sgst) || 0;
                    const cgst = Number(item.cgst) || 0;
                    const igst = Number(item.igst) || 0;
                    const netAmount = Number(item.netAmount) || 0;
                    const billDiscountAmount = Number(item.billDiscountAmount) || 0;

                    return {
                        id: item.Id,
                        dcliId: item.dcliId || '',
                        serialNumber: item.serialNumber || '',
                        dcName: item.dcName || '',
                        productName: item.productName || '',
                        status: item.status || '',
                        condition: item.condition || '',
                        suppliedDate: item.suppliedDate || '',
                        billDiscountAmount: billDiscountAmount,
                        unitPrice: item.unitPrice || 0,
                        creditNoteAmount: item.creditNoteAmount,
                        SGST: sgst,
                        CGST: cgst,
                        IGST: igst,
                        netAmount: netAmount - billDiscountAmount,
                        originalSGST: sgst,
                        originalCGST: cgst,
                        originalIGST: igst,
                        originalNetAmount: netAmount,
                        orignialTaxablePrice: item.unitPrice - billDiscountAmount,
                        selectedSchemeDiscount: item.selectedSchemeDiscount || 0,
                        taxablePrice: item.discountedTaxablePrice !== undefined ? item.discountedTaxablePrice : item.unitPrice - billDiscountAmount,
                        isSelected: true,
                        patientFirstName: item.patientFirstName,
                        patientLastName: item.patientLastName,
                        patientAge: item.patientAge,
                        patientRegisterNumber: item.patientRegisterNumber,
                        ipNumber: item.ipNumber,
                        cathNumber: item.cathNumber,
                        doctorName: item.doctorName,
                        patientGender: item.patientGender,
                        implantDate: item.implantDate
                    };
                });
            })
            .catch(error => {
                console.error('Error fetching line items:', error);
            });
    }
    get isAllSelectedCP() {
        return this.warehouseLineItemOptionsCP.length > 0 && this.warehouseLineItemOptionsCP.every(item => item.isSelected);
    }

    @track selectedCreditNotes = [];

    handleCNChange(event) {
        const selectedValue = event.detail.value;
        const selectedOption = this.creditNoteOptions.find(opt => opt.value === selectedValue);

        const alreadySelected = this.selectedCreditNotes.some(note => note.value === selectedValue);
        if (!alreadySelected && selectedOption) {
            this.selectedCreditNotes = [...this.selectedCreditNotes, selectedOption];
        }
        this.creditNote = null;
    }

    handleRemoveCreditNote(event) {
        const noteIdToRemove = event.detail.name;
        this.selectedCreditNotes = this.selectedCreditNotes.filter(note => note.value !== noteIdToRemove);
    }

    handleSelectAllCP(event) {
        const checked = event.target.checked;
        this.warehouseLineItemOptionsCP = this.warehouseLineItemOptionsCP.map(item => ({
            ...item,
            isSelected: checked
        }));
    }

    handleSchemeChangeCP(event) {
        this.selectedScheme = event.detail.value;
        const schemeObj = this.schemeOptions.find(s => s.value === this.selectedScheme);
        if (!schemeObj) return;

        this.selectedSchemeName = schemeObj.label;
        const discount = schemeObj.discount || 0;
        const factor = (100 - discount) / 100;

        this.warehouseLineItemOptionsCP = this.warehouseLineItemOptionsCP.map(item => {
            if (!item.isSelected) return item;

            const billDiscountAmount = item.billDiscountAmount || 0;
            const baseSGST = item.originalSGST || 0;
            const baseCGST = item.originalCGST || 0;
            const baseIGST = item.originalIGST || 0;
            const baseNet = item.originalNetAmount || 0;

            const discountedTaxablePrice = factor * (item.unitPrice - billDiscountAmount);

            const basicAmount = baseNet - (baseSGST + baseCGST + baseIGST);
            const discountedBasic = +(basicAmount * factor).toFixed(2);

            const sgstRate = baseSGST / basicAmount || 0;
            const cgstRate = baseCGST / basicAmount || 0;
            const igstRate = baseIGST / basicAmount || 0;

            const newSGST = +(discountedTaxablePrice * sgstRate).toFixed(2);
            const newCGST = +(discountedTaxablePrice * cgstRate).toFixed(2);
            const newIGST = +(discountedTaxablePrice * igstRate).toFixed(2);
            const newNet = +(discountedTaxablePrice + newSGST + newCGST + newIGST).toFixed(2);

            return {
                ...item,
                selectedScheme: this.selectedScheme,
                selectedSchemeName: this.selectedSchemeName,
                selectedSchemeDiscount: discount,
                taxablePrice: +discountedTaxablePrice.toFixed(2),
                SGST: newSGST,
                CGST: newCGST,
                IGST: newIGST,
                netAmount: newNet,
                discountedTaxablePrice: discountedTaxablePrice
            };
        });
    }

    handleRowSelectionCP(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;

        this.warehouseLineItemOptionsCP = this.warehouseLineItemOptionsCP.map(item => {
            if (item.serialNumber === itemId) {
                return { ...item, isSelected: checked };
            }
            return item;
        });
    }

    handleSaveInvoiceCP() {
        // Calculate total net amount of selected items
        const totalNetAmount = this.warehouseLineItemOptionsCP
            .filter(item => item.isSelected)
            .reduce((sum, item) => sum + parseFloat(item.netAmount || 0), 0);

        const totalCreditNotes = this.selectedCreditNotes.reduce((sum, item) => {
            // Remove all non-digit/decimal chars to extract amount
            const amountStr = item.label.replace(/[^\d.]/g, '');
            return sum + parseFloat(amountStr || 0);
        }, 0);

        if (totalCreditNotes > totalNetAmount) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Total credit note amount exceeds total net amount. Please remove some credit notes.',
                    variant: 'error'
                })
            );
            return;
        }

        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
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

        const selectedLineItems = this.warehouseLineItemOptionsCP
            .filter(item => item.isSelected)
            .map(item => ({
                id: item.id,
                scheme: item.selectedSchemeName,
                SGST: item.SGST || 0,
                CGST: item.CGST || 0,
                IGST: item.IGST || 0,
                netAmount: item.netAmount || 0,
                billDiscountAmount: item.billDiscountAmount || 0,
                patientFirstName: item.patientFirstName,
                patientLastName: item.patientLastName,
                patientAge: item.patientAge,
                patientRegisterNumber: item.patientRegisterNumber,
                ipNumber: item.ipNumber,
                cathNumber: item.cathNumber,
                doctorName: item.doctorName,
                patientGender: item.patientGender,
                implantDate: item.implantDate,
                dcliId: item.dcliId
            }));

        if (selectedLineItems.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select at least one product.',
                    variant: 'error'
                })
            );
            return;
        }

        const invoiceDataCP = {
            comment: this.comment,
            invoiceType: this.selectedInvoiceType,
            selectedChannelPartner: this.selectedChannelPartner,
            selectedDeliveryChallan: this.selectedDeliveryChallan,
            invoiceCreationType: this.showInvoiceByScan,
            lineItemIds: selectedLineItems,
            creditNoteId: this.selectedCreditNotes.length > 0 ? this.selectedCreditNotes.map(note => note.value) : null
        };
        this.invoiceLableCP = 'Creating Invoice...';
        this.disableCreateInvoiceBtn = true;
        console.log('invoice data CP is ', invoiceDataCP);
        saveInvoiceCP({ invoiceDataCP: JSON.stringify(invoiceDataCP), selectedInvoice: this.selectedInvoice })
            .then(result => {
                this.isSubmitDisabled = true;
                this.showSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Invoice saved successfully',
                        variant: 'success'
                    })
                );
                this.showSuccessModal = true;
                this.isChannelPartnerMode = false;
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: 'Invoice__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error?.body?.message ? error?.body?.message : error?.message || 'Something went wrong. Please try again later.',
                        variant: 'error'
                    })
                );
                this.isChannelPartnerMode = false;
                console.error('Error creating invoice:', error);
                this.showErrorModal = true;
            }).finally(() => {
                this.invoiceLableCP = 'Create Invoice';
                this.disableCreateInvoiceBtn = false;
            });
    }

    get snScanPlaceholder() {
        return `Scan Serial Number (${SERIAL_NUMBER_LENGTH} characters)`
    }

    get serialNumberDisable() {
        return this.selectedHospitalId ? false : true;
    }
    get serialNumberDisableCP() {
        return this.selectedChannelPartner ? false : true;
    }
    handleScan(event) {
        const serialNumber = event.target.value;

        if (serialNumber && serialNumber.length === SERIAL_NUMBER_LENGTH) {

            console.log('this.warehouseLineItem', this.warehouseLineItems);
            const isDuplicate = this.warehouseLineItems.some(item => item.record.Serial_Number__c === serialNumber);

            console.log('IsDuplicate: ', isDuplicate)
            if (isDuplicate) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Duplicate Detected',
                        message: `Serial number ${serialNumber} has already been scanned`,
                        variant: 'warning'
                    }));
                event.target.value = '';
                return;
            }

            getWarehouseProductLineItemsBySerialNumber({ hospitalId: this.selectedHospitalId, serialNumber: serialNumber })
                .then(wrapperList => {
                    if (wrapperList && wrapperList.length > 0) {
                        const newItems = wrapperList.map(wrapper => ({
                            ...wrapper,
                            isSelected: false,
                            selectedScheme: null,
                            selectedSchemeName: null
                        }));

                        this.warehouseLineItems = [...this.warehouseLineItems, ...newItems];

                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: `Serial number ${serialNumber} has been scanned successfully.`,
                                variant: 'success'
                            }));
                        event.target.value = '';
                    } else {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error',
                                message: `The serial number ${serialNumber} could not be found or is invalid`,
                                variant: 'error'
                            }));
                    }
                })
                .catch(error => {
                    console.error('Error fetching warehouse product line items', error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: error.body ? error.body.message : 'An unknown error occurred.',
                            variant: 'error'
                        }));
                })
                .finally(() => {
                    event.target.value = '';
                });
        }
    }
    handleScanCP(event) {
        const serialNumber = event.target.value;
        const inputElement = event.target;

        if (serialNumber && serialNumber.length === SERIAL_NUMBER_LENGTH) {

            const isDuplicate = this.warehouseLineItemOptionsCP.some(item => item.serialNumber === serialNumber);

            if (isDuplicate) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Duplicate Detected',
                        message: `Serial number ${serialNumber} has already been scanned`,
                        variant: 'warning'
                    })
                );
                inputElement.value = '';
                event.target.value='';
                return;
            }

            getChannelPartnerLineItemsBySerialNumber({ consigneeId: this.selectedChannelPartner, serialNumber: serialNumber })
                .then(wrapperList => {
                    if (wrapperList && wrapperList.length > 0) {
                        console.log('wrapperList: ', wrapperList);
                        const newItem = wrapperList.map(item => {
                            const sgst = Number(item.sgst) || 0;
                            const cgst = Number(item.cgst) || 0;
                            const igst = Number(item.igst) || 0;
                            const netAmount = Number(item.netAmount) || 0;
                            const billDiscountAmount = Number(item.billDiscountAmount) || 0;


                            return {
                                id: item.Id,
                                serialNumber: item.serialNumber || '',
                                dcName: item.dcName || '',
                                dcliId: item.dcliId || '',
                                productName: item.productName || '',
                                status: item.status || '',
                                condition: item.condition || '',
                                suppliedDate: item.suppliedDate || '',
                                billDiscountAmount: billDiscountAmount,
                                unitPrice: item.unitPrice || 0,
                                creditNoteAmount: item.creditNoteAmount,
                                SGST: sgst,
                                CGST: cgst,
                                IGST: igst,
                                netAmount: netAmount - billDiscountAmount,
                                originalSGST: sgst,
                                originalCGST: cgst,
                                originalIGST: igst,
                                originalNetAmount: netAmount,
                                orignialTaxablePrice: item.unitPrice - billDiscountAmount,
                                selectedSchemeDiscount: item.selectedSchemeDiscount || 0,
                                taxablePrice: item.discountedTaxablePrice !== undefined ? item.discountedTaxablePrice : item.unitPrice - billDiscountAmount,
                                isSelected: true,
                                patientFirstName: item.patientFirstName,
                                patientLastName: item.patientLastName,
                                patientAge: item.patientAge,
                                patientRegisterNumber: item.patientRegisterNumber,
                                ipNumber: item.ipNumber,
                                cathNumber: item.cathNumber,
                                doctorName: item.doctorName,
                                patientGender: item.patientGender,
                                implantDate: item.implantDate
                            };
                        }
                        );
                        this.warehouseLineItemOptionsCP = [...this.warehouseLineItemOptionsCP, ...newItem];

                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: `Serial number ${serialNumber} has been scanned successfully.`,
                                variant: 'success'
                            })
                        );
                    } else {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error',
                                message: `The serial number ${serialNumber} could not be found or is invalid`,
                                variant: 'error'
                            })
                        );
                    }
                })
                .catch(error => {
                    console.error('Error fetching warehouse product line items', error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: error.body ? error.body.message : 'An unknown error occurred.',
                            variant: 'error'
                        })
                    );
                })
                .finally(() => {
                    event.target.value='';
                    if (inputElement) {
                        inputElement.value = '';
                    }
                });
        }
    }
    get patientFullName() {
        return `${this.patientFirstName || ''} ${this.patientLastName || ''}`.trim();
    }
    handleViewPatientDetails(event) {
        const serialNumber = event.target.dataset.serial;
        const foundItem = this.warehouseLineItemOptionsCP.find(item => item.serialNumber === serialNumber);
        console.log('foundItem: ', foundItem);
        if (foundItem) {
            this.patientFirstName = foundItem.patientFirstName;
            this.patientLastName = foundItem.patientLastName;
            this.patientAge = foundItem.patientAge;
            this.patientRegisterNumber = foundItem.patientRegisterNumber;
            this.ipNumber = foundItem.ipNumber;
            this.cathNumber = foundItem.cathNumber;
            this.doctorName = foundItem.doctorName;
            this.patientGender = foundItem.patientGender;
            this.implantDate = foundItem.implantDate;

            this.showPatientDetail = true;
        }
    }

    handleClose() {
        this.showPatientDetail = false;
    }
}