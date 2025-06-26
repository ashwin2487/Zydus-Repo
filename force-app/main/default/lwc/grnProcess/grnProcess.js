import { LightningElement, api, track, wire } from 'lwc';
import getDeliveryChallanDetails from '@salesforce/apex/GRNController.getDeliveryChallanDetails';
import processGRN from '@salesforce/apex/GRNController.processGRN';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class GrnProcess extends LightningElement {
  @api recordId;

  @track lineItems = [];
  @track warehouseOptions = [];
  @track error;

  @track headerStatus = '';
  @track headerRejectionReason = '';
  @track headerWarehouse = '';
  @track rejectionComment = '';

  statusOptions = [
    { label: 'Accept', value: 'Accepted' },
    { label: 'Reject', value: 'Rejected' }
  ];

  rejectionReasons = [
    { label: 'Damaged', value: 'Damaged' },
    { label: 'Wrong Item', value: 'Wrong Item' },
    { label: 'Expired', value: 'Expired' },
    { label: 'Others', value: 'Others' }

  ];

  get isHeaderRejectionDisabled() {
    return this.headerStatus !== 'Rejected';
  }

  @wire(getDeliveryChallanDetails, { challanId: '$recordId' })
  wiredChallan({ data, error }) {
    if (data) {
      this.warehouseOptions = data.warehouseOptions;
      this.lineItems = data.lineItems.map(item => ({
        ...item,
        isRejected: item.status === 'Rejected',
        isSelected: false,
        selectedWarehouseId: data.warehouseOptions.length === 1 ? data.warehouseOptions[0].value : '',
        selectedWarehouseName: data.warehouseOptions.length === 1 ? data.warehouseOptions[0].label : ''
      }));
      this.error = undefined;
    } else if (error) {
      this.error = error.body?.message || error.message;
    }
  }

  handleRowSelection(event) {
    const itemId = event.target.dataset.id;
    const isChecked = event.target.checked;
    this.lineItems = this.lineItems.map(item =>
      item.id === itemId ? { ...item, isSelected: isChecked } : item
    );
  }

  handleSelectAll(event) {
    const isChecked = event.target.checked;
    this.lineItems = this.lineItems.map(item => ({
      ...item,
      isSelected: isChecked
    }));
  }

  get isAllSelected() {
    return this.lineItems.length > 0 && this.lineItems.every(item => item.isSelected);
  }


  handleHeaderStatusChange(event) {
    this.headerStatus = event.detail.value;

    this.lineItems = this.lineItems.map(item => {
      if (item.isSelected) {
        return {
          ...item,
          status: this.headerStatus,
          isRejected: this.headerStatus === 'Rejected',
          rejectionReason: this.headerStatus === 'Rejected' ? this.headerRejectionReason : '',
          isSelected: this.headerStatus === 'Rejected' ? true : false,
          showRejectionCommentBox: this.headerStatus === 'Rejected' && this.headerRejectionReason ==='Others' ? true : false
        };
      }
      return item;
    });

    if (this.headerStatus !== 'Rejected') {
      this.headerRejectionReason = '';
    }
  }

  handleHeaderRejectionChange(event) {
    this.headerRejectionReason = event.detail.value;

    this.lineItems = this.lineItems.map(item => {
      if (item.isSelected && item.status === 'Rejected') {

        return {
          ...item,
          rejectionReason: this.headerRejectionReason,
          showRejectionCommentBox: this.headerRejectionReason === 'Others'
        };
      }
      return item;
    });
  }

  handleChangeRejectionCommentChange(event) {
    const comment = event.detail.value;
    this.rejectionComment = comment;

    this.lineItems = this.lineItems.map(item => {
      if (
        item.isSelected &&
        item.status === 'Rejected' &&
        item.rejectionReason &&
        item.rejectionReason.trim() === 'Others'
      ) {
        return {
          ...item,
          rejectionComment: comment
        };
      }
      return item;
    });
  }


  handleHeaderWarehouseChange(event) {
    this.headerWarehouse = event.detail.value;

    const selectedWarehouse = this.warehouseOptions.find(
      option => option.value === this.headerWarehouse
    );

    const warehouseLabel = selectedWarehouse ? selectedWarehouse.label : '';

    this.lineItems = this.lineItems.map(item => {
      if (item.isSelected) {
        return {
          ...item,
          selectedWarehouseId: this.headerWarehouse,
          selectedWarehouseName: warehouseLabel,
          isSelected: false
        };
      }
      return item;
    });
  }

  handleSubmit() {
    const invalidItems = this.lineItems.filter(item => !item.status);
    const noWarehouseSelected = this.lineItems.filter(item => !item.selectedWarehouseId);

    if (invalidItems.length > 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Validation Error',
          message: 'Please select status for all line items before submitting.',
          variant: 'error'
        })
      );
      return;
    }

    if (noWarehouseSelected.length > 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Validation Error',
          message: 'Please assign a warehouse to all line items before submitting.',
          variant: 'error'
        })
      );
      return;
    }

    console.log('this.rejectionComment', this.rejectionComment);
    console.log('lineItems', this.lineItems);

    processGRN({
      challanId: this.recordId,
      lineItems: this.lineItems
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Success',
            message: 'GRN processed successfully.',
            variant: 'success'
          })
        );
        this.dispatchEvent(new CloseActionScreenEvent());
      })
      .catch(error => {
        this.error = error.body?.message || error.message;
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error',
            message: this.error,
            variant: 'error'
          })
        );
      });
  }
}