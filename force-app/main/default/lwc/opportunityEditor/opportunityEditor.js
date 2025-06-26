import { LightningElement, api, track } from 'lwc';
import getOpportunityLineItems from '@salesforce/apex/OpportunityController.getOpportunityLineItems';
import saveOpportunityLineItems from '@salesforce/apex/OpportunityController.saveOpportunityLineItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OpportunityEditor extends LightningElement {
    @api opportunityId;
    @track lineItems = [];

    connectedCallback() {
        getOpportunityLineItems({ opportunityId: this.opportunityId })
            .then(data => {
                this.lineItems = JSON.parse(JSON.stringify(data));
            });
    }

    handleChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = parseFloat(event.target.value);
        this.lineItems = this.lineItems.map(item => {
            if (item.Id === id) {
                item[field] = value;
            }
            return item;
        });
    }

    handleSave() {
        saveOpportunityLineItems({ items: this.lineItems })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Line items updated.',
                    variant: 'success'
                }));
                this.dispatchEvent(new CustomEvent('close'));
            });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}