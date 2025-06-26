import { LightningElement, api, wire, track } from 'lwc';
import getOpportunities from '@salesforce/apex/OpportunityController.getOpportunities';
import approveOpportunity from '@salesforce/apex/OpportunityController.approveOpportunity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class OpportunityManager extends LightningElement {
    @api recordId;
    @track opportunities;
    @track selectedOpportunityId;
    @track showEditor = false;

    wiredResult;
    @wire(getOpportunities, { accountId: '$recordId' })
    wiredOpps(result) {
        this.wiredResult = result;
        if (result.data) {
            this.opportunities = result.data;
        } else if (result.error) {
            console.error('Error fetching opportunities:', result.error);
        }
    }
    handleApprove(event) {
        const oppId = event.target.dataset.id;

        approveOpportunity({ opportunityId: oppId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Opportunity approved and order created.',
                    variant: 'success'
                }));
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                let errorMessage = 'An unexpected error occurred.';
                if (error && error.body && error.body.message) {
                    errorMessage = error.body.message;
                } else if (error && error.message) {
                    errorMessage = error.message;
                }

                console.error('Error in handleApprove:', error);

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: errorMessage,
                    variant: 'error'
                }));
            });
    }
    handleEdit(event) {
        this.selectedOpportunityId = event.target.dataset.id;
        this.showEditor = true;
    }
    handleEditorClose() {
        this.showEditor = false;
        refreshApex(this.wiredResult);
    }
}