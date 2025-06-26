import { LightningElement, track, wire } from 'lwc';
import getUserAccountsAndHospitals from '@salesforce/apex/InvoiceCreationController.getUserAccountsAndHospitals';
import getWarehouseProductLineItems from '@salesforce/apex/InvoiceCreationController.getWarehouseProductLineItems';
import saveInvoice from '@salesforce/apex/InvoiceCreationController.saveInvoice';
import existingDoctor from '@salesforce/apex/InvoiceCreationController.existingDoctor';
import RelatedDCToHosp from '@salesforce/apex/InvoiceCreationController.RelatedDCToHosp';
import getScheme from '@salesforce/apex/InvoiceCreationController.getScheme';
import getCreditNoteOptions from '@salesforce/apex/InvoiceCreationController.getCreditNoteOptions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSubChannelPartnerOptions from '@salesforce/apex/InvoiceCreationController.getSubChannelPartnerOptions';
import getDeliveryChallanForChannelPartner from '@salesforce/apex/InvoiceCreationController.getDeliveryChallanForChannelPartner';
import getInvoiceData from '@salesforce/apex/InvoiceCreationController.getInvoiceData';
import getInvoices from '@salesforce/apex/InvoiceCreationController.getInvoices';
import getChannelPartnerLineItems from '@salesforce/apex/InvoiceCreationController.getChannelPartnerLineItems';
import saveInvoiceCP from '@salesforce/apex/InvoiceCreationController.saveInvoiceCP';
import getPaymentModePicklistValues from '@salesforce/apex/InvoiceCreationController.getPaymentModePicklistValues';
import existingCATHNumber from '@salesforce/apex/InvoiceCreationController.existingCATHNumber';
export default class InvoiceCreation extends LightningElement {
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
    @track uploadedFileName = '';
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

    blurTimeout
    genderOptions = [
        { label: 'Male', value: 'Male' },
        { label: 'Female', value: 'Female' }
    ];
    invoiceCreationOptions = [
        { label: 'Hospital Invoice', value: 'hospital' },
        { label: 'Channel Partner Invoice', value: 'channelPartner' }
    ]


    handleInvoiceCreationTypeChange(event) {
        this.selectedInvoiceCreationType = event.detail.value;
        this.isHospitalMode = this.selectedInvoiceCreationType === 'hospital';
        this.isChannelPartnerMode = this.selectedInvoiceCreationType === 'channelPartner';
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

            this.hospitalOptions = Object.entries(data.hospitals).map(([id, name]) => ({
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

    handleInvoiceTypeChange(event) {
        this.selectedInvoiceType = event.detail.value;
    }
    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value;
    }

    handleHospitalChange(event) {
        this.selectedHospitalId = event.detail.value;
        this.selectedLineItemIds = [];
        this.fetchDeliveryChallan();
    }

    fetchDeliveryChallan() {
        RelatedDCToHosp({ HospId: this.selectedHospitalId })
            .then(result => {
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
        this.uploadedFileIds = event.detail.files;
        if (this.uploadedFileIds.length > 0) {
            this.uploadedFileId = uploadedFiles[0].documentId;
            this.uploadedFileName = uploadedFiles[0].name;
        }
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
            return;
        }

        const selectedLineItems = this.warehouseLineItems
            .filter(item => item.isSelected)
            .map(item => ({
                id: item.record.Id,
                SGST: item.discountedSGST !== undefined ? item.discountedSGST : item.cgst || 0,
                CGST: item.discountedCGST !== undefined ? item.discountedCGST : item.sgst || 0,
                IGST: item.discountedIGST !== undefined ? item.discountedIGST : item.igst || 0,
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

        console.log('selectedLineItems',JSON.stringify(selectedLineItems));

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

        console.log('invoiceData', invoiceData);

        saveInvoice({ invoiceData: JSON.stringify(invoiceData) })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Invoice saved successfully',
                    variant: 'success'
                }));
                this.isHospitalMode = false;
            })
            .catch(error => {
                console.error('Error saving invoice:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to save invoice. ' + (error.body?.message || ''),
                    variant: 'error'
                }));
            });
    }

    get disableDC() {
        return !this.selectedHospitalId;
    }

    get warehouseLineItemOptions() {
        return this.warehouseLineItems.map(item => ({
            Id: item.record.Id,
            Serial_Number__c: item.record.Serial_Number__c || 'Unnamed',
            Status__c: item.record.Status__c,
            Condition__c: item.record.Condition__c,
            Supplied_Date__c: item.record.Supplied_Date__c,
            ProductName: item.record.Warehouse__r?.Zydus_Product__r?.Name || 'Unknown',
            DC: item.record.GRN__r?.Delivery_Challan__r?.Name || 'Unknown',
            SGST: item.discountedSGST !== undefined ? item.discountedSGST : item.cgst || 0,
            CGST: item.discountedCGST !== undefined ? item.discountedCGST : item.sgst || 0,
            IGST: item.discountedIGST !== undefined ? item.discountedIGST : item.igst || 0,
            billDiscountAmount: item.record?.Delivery_Challan_Line_Item__r?.Zydus_Price_Book_Entry__r?.Bill_Discount_Amount__c || 0,
            orginalNetAmount: item.netAmount,
            netAmount: (item.discountedNetAmount !== undefined ? item.discountedNetAmount : item.netAmount) - (item.record?.Delivery_Challan_Line_Item__r?.Zydus_Price_Book_Entry__r?.Bill_Discount_Amount__c || 0),
            isSelected: item.isSelected,
            selectedScheme: item.selectedScheme,
            discount: item.discount || 0,
            selectedSchemeName: item.selectedSchemeName
        }));
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

            const basic = item?.record?.Unit_Price__c;
            const discountedBasic = basic * factor;

            const newCGST = +(discountedBasic * (item.cgst / basic) || 0).toFixed(2);
            const newSGST = +(discountedBasic * (item.sgst / basic) || 0).toFixed(2);
            const newIGST = +(discountedBasic * (item.igst / basic) || 0).toFixed(2);
            const newNet = +(discountedBasic + newCGST + newSGST + newIGST).toFixed(2);

            return {
                ...item,
                selectedScheme: this.selectedScheme,
                selectedSchemeName: this.selectedSchemeName,
                discountedCGST: newCGST,
                discountedSGST: newSGST,
                discountedIGST: newIGST,
                discountedNetAmount: newNet,
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

    handleChannelPartnerSelect(event) {
        this.selectedChannelPartner = event.detail.value;

        getDeliveryChallanForChannelPartner({ Id: this.selectedChannelPartner })
            .then(result => {
                console.log('Delivery Challans for Channel Partner:', result);
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

    handleChannelPartnerDeliveryChallanChange(event) {
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
                this.errorMessage = 'Failed to load Invoices. Please try again.';
            });
    }

    handleInvoiceChange(event) {
        this.selectedInvoice = event.detail.value;

        getInvoiceData({ invoiceId: this.selectedInvoice })

            .then(data => {
                if (data) {
                    this.patientFirstNameCP = data.Patient_First_Name__c;
                    this.patientLastNameCP = data.Patient_Last_Name__c;
                    this.patientAgeCP = data.Patient_Age__c;
                    this.patientGenderCP = data.Patient_Gender__c;
                    this.comment = data.Comment_Remark__c;
                    this.doctorInputCP = data.Doctor_Name__c;
                    this.ipNumberCP = data.IP_Number__c;
                    this.cathNumberCP = data.CATH_Number__c;
                    this.implantDateCP = data.Date_of_Implant__c;
                    this.invoiceType = data.Invoice_Type__c;
                    this.patientRegisterNumberCP = data.Patient_Register_Number__c;
                }
            })
            .catch(error => {
                console.error('Error fetching invoice data:', error);
            });
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

    handlePaymentModeChange(event) {
        this.paymentMode = event.detail.value;
        console.log('Selected Payment Mode:', this.paymentMode);
        this.fetchCPLineItems(this.selectedDeliveryChallan);
    }

    fetchCPLineItems(dcId) {
        console.log('dcId', dcId);
        getChannelPartnerLineItems({ dcId: dcId , invoiceId: this.selectedInvoice})
            .then(result => {
                console.log('Line Items:', result);
                this.warehouseLineItemOptionsCP = result.map(item => {
                    const sgst = Number(item.sgst) || 0;
                    const cgst = Number(item.cgst) || 0;
                    const igst = Number(item.igst) || 0;
                    const netAmount = Number(item.netAmount) || 0;
                    const billDiscountAmount = Number(item.billDiscountAmount) || 0;

                    return {
                        id: item.Id,
                        serialNumber: item.serialNumber || '',
                        dcName: item.dcName || '',
                        productName: item.productName || '',
                        status: item.status || '',
                        condition: item.condition || '',
                        suppliedDate: item.suppliedDate || '',
                        billDiscountAmount: billDiscountAmount,
                        SGST: sgst,
                        CGST: cgst,
                        IGST: igst,
                        netAmount: netAmount-billDiscountAmount,
                        originalSGST: sgst,
                        originalCGST: cgst,
                        originalIGST: igst,
                        originalNetAmount: netAmount,
                        selectedSchemeDiscount: item.selectedSchemeDiscount || 0,
                        isSelected: true
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

            const basicAmount = baseNet - (baseSGST + baseCGST + baseIGST);
            const discountedBasic = +(basicAmount * factor).toFixed(2);

            const sgstRate = baseSGST / basicAmount || 0;
            const cgstRate = baseCGST / basicAmount || 0;
            const igstRate = baseIGST / basicAmount || 0;

            const newSGST = +(discountedBasic * sgstRate).toFixed(2);
            const newCGST = +(discountedBasic * cgstRate).toFixed(2);
            const newIGST = +(discountedBasic * igstRate).toFixed(2);
            const newNet = +(discountedBasic + newSGST + newCGST + newIGST - billDiscountAmount).toFixed(2);

            return {
                ...item,
                selectedScheme: this.selectedScheme,
                selectedSchemeName: this.selectedSchemeName,
                selectedSchemeDiscount: discount,
                SGST: newSGST,
                CGST: newCGST,
                IGST: newIGST,
                netAmount: newNet
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
                billDiscountAmount: item.billDiscountAmount || 0
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
            paymentMode: this.paymentMode,
            implantDateCP: this.implantDateCP,
            ipNumberCP: this.ipNumberCP,
            cathNumberCP: this.cathNumberCP,
            patientFirstNameCP: this.patientFirstNameCP,
            patientLastNameCP: this.patientLastNameCP,
            patientAgeCP: this.patientAgeCP,
            patientRegisterNumberCP: this.patientRegisterNumberCP,
            patientGenderCP: this.patientGenderCP,
            doctorInputCP: this.doctorInputCP,
            invoiceType: this.selectedInvoiceType,
            selectedChannelPartner: this.selectedChannelPartner,
            selectedDeliveryChallan: this.selectedDeliveryChallan,
            lineItemIds: selectedLineItems,
            creditNoteId: this.selectedCreditNotes.length > 0 ? this.selectedCreditNotes.map(note => note.value) : null
        };
        console.log('invoice data is ', invoiceDataCP);
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
            });
    }
}