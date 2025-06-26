import { LightningElement, track, wire } from 'lwc';
import getHospitalOptions from '@salesforce/apex/onboardingController.getHospitalOptions';

export default class HospitalOnBoardingProcess extends LightningElement {
    @track selectedHospitals = [];
    hospitalOptions = [];

    @wire(getHospitalOptions)
    wiredHospitalOptions({ error, data }) {
        if (data) {
            this.hospitalOptions = data.map(item => ({ label: item.Name, value: item.Id }));
        } else if (error) {
            console.error('Error fetching hospitals:', error);
        }
    }

    handleHospitalChange(event) {
        this.selectedHospitals = event.detail.value;
    }

    handleSubmit() {
        const payload = {
            selectedHospitals: this.selectedHospitals
        };
        console.log('Submitting Hospital:', JSON.stringify(payload));
    }

    handleSubmitHospitalForApproval() {
        const allValid = [...this.template.querySelectorAll('lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (allValid) {
            this.handleSubmit();
        } else {
            console.warn('Please select hospital(s).');
        }
    }
}