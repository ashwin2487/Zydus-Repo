import { LightningElement, track, api,wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateAccount from '@salesforce/apex/DLRenewalController.updateAccountFields';
import { CloseActionScreenEvent } from 'lightning/actions';
const MAX_FILE_SIZE = 5 * 1024 * 1024;

export default class DLExpiryHandler extends LightningElement {
    @track selectedOption = '';
    @track remarks = '';
    @track expiryDate;
    @track file;
    @track extension = '';
    @track showFileUploader = false;
    @track showTextInput = false;
    @track showExpiryOptions = false;
    @track showDatePicker = false;
    @track showSubmitButton = false;
    @api recordId;
    fileName = '';
    fileData;


    radioOptions = [
        { label: 'Submitted for Renewal', value: 'submittedForRenewal' },
        { label: 'Renewed DL', value: 'renewedDL' }
    ];

    expiryOptions = [
        { label: '15 Days', value: '15' },
        { label: '30 Days', value: '30' }
    ];

    handleDLModalClose(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleRadioChange(event) {
        this.selectedOption = event.detail.value;
        this.resetFields();

        if (this.selectedOption === 'submittedForRenewal') {
            this.showFileUploader = true;
            this.showTextInput = true;
            this.showExpiryOptions = true;
            this.showDatePicker = false;
            this.showSubmitButton = true;
        } else if (this.selectedOption === 'renewedDL') {
            this.showDatePicker = true;
            this.showFileUploader = true;
            this.showTextInput = true;
            this.showExpiryOptions = false;
            this.showSubmitButton = true;
        }
    }

    handleRemarkChange(event) {
        this.remarks = event.target.value;
    }

    handleFileUpload(event) {
        const file = event.detail.files[0];

        if (!file) { return; }

        if (file.size > MAX_FILE_SIZE) {
            alert(`"${file.name}" is too large. Maximum per-file size is 5 MB.`);
            return;
        }

        const reader = new FileReader();

        reader.onloadend = () => {
            const base64 = reader.result.split(',')[1];
            this.fileName = file.name;

            this.fileData = base64;
        };

        reader.onerror = () => {
            console.error('File reading error', reader.error);
            alert('There was an error reading the file.');
        };
        reader.readAsDataURL(file);
    }


    removeFile() {
        this.fileName = '';
        this.fileData = '';

        const fileInput = this.template.querySelector('lightning-input[type="file"]');
        if (fileInput) {
            fileInput.value = null;
        }
    }
    handleExpiryExtension(event) {
        this.extension = event.detail.value;
        const currentDate = new Date();
        if (this.extension === '15') {
            this.expiryDate = new Date();
            this.expiryDate.setDate(currentDate.getDate() + 15);
        } else if (this.extension === '30') {
            this.expiryDate = new Date();
            this.expiryDate.setDate(currentDate.getDate() + 30);
        }
    }

    handleDateChange(event) {
        this.expiryDate = event.target.value;
    }

    async handleSubmit() {
        if (this.remarks === '' || this.expiryDate === '' || this.selectedOption == '' || this.fileName == '') {
            this.showToast('Error', 'Please fill all the fields', 'error');
            return;
        }

        updateAccount({
            accountId: this.recordId,
            remarks: this.remarks,
            expiryDate: this.expiryDate,
            fileName: this.fileName,
            base64FileData: this.fileData,
            option: this.selectedOption
        })
            .then(() => {
                this.showToast('Success', 'Account updated successfully!', 'success');
                this.handleDLModalClose();
            })
            .catch((error) => {
                this.showToast('Error', 'Error updating account: ' + error.body.message, 'error');
                this.handleDLModalClose();
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }

    resetFields() {
        this.remarks = '';
        this.expiryDate = null;
        this.file = null;
        this.extension = '';
        this.showFileUploader = false;
        this.showTextInput = false;
        this.showExpiryOptions = false;
        this.showDatePicker = false;
        this.showSubmitButton = false;
    }
}