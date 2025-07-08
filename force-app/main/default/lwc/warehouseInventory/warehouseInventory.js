import { LightningElement, track } from 'lwc';
import getWarehousesOptions from '@salesforce/apex/WarehouseInventoryController.getWarehousesOptions';
import getInventoryData from '@salesforce/apex/WarehouseInventoryController.getInventoryData';
import getWPLIs from '@salesforce/apex/WarehouseInventoryController.getWPLIs';
import createReverseSupplyOrders from '@salesforce/apex/WarehouseInventoryController.createReverseSupplyOrders';
import shouldRSObtnVisible from '@salesforce/apex/WarehouseInventoryController.shouldRSObtnVisible';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
export default class WarehouseInventory extends NavigationMixin(LightningElement) {
    @track warehouseOptions = [];
    @track selectedWarehouseId;
    @track tableData = [];
    @track showReverseTable = false;
    @track damagedProducts = [];
    @track isProceedDisabled = true;
    @track isWarehouseSelected = false;
    @track wpliData = [];
    @track selectedWpliIds = [];
    @track selectedCondition = 'All';
    @track isLoading = false;
    @track selectedStatus = 'Free';
    @track emptyArray = [];
    @track reverseSOTableData = [];
    showReverseSOBtn = false;
    @track wpliData = [];

    connectedCallback() {
        getWarehousesOptions()
            .then(result => {
                console.log('Warehousese:',result);
                this.warehouseOptions = result.map(w => ({
                    label: w.Name,
                    value: w.Id
                }));
            })
            .catch(error => {
                console.error('Error fetching warehouses:', error);
            });
    }

    columns = [
        { label: 'Warehouse', fieldName: 'warehouseName', type: 'text', sortable: true, initialWidth: 200 },
        { label: 'Product Name', fieldName: 'productName', type: 'text', sortable: true, initialWidth: 200 },
        { label: 'Material Code', fieldName: 'materialCode', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Brand', fieldName: 'brand', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Size', fieldName: 'size', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'UOM', fieldName: 'uom', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Batch', fieldName: 'batchNumber', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Serial Number', fieldName: 'serialNumber', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Manufactured Date', fieldName: 'manufacturedDate', type: 'date', sortable: true, initialWidth: 180 },
        { label: 'Expiry Date', fieldName: 'expiryDate', type: 'date', sortable: true, initialWidth: 150 },
        { label: 'Expiry Category', fieldName: 'expiryCategory', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Balance Exp Days', fieldName: 'balanceExpDays', type: 'number', sortable: true, initialWidth: 150 },
        { label: 'Total Value (MRP)', fieldName: 'totalValueMRP', type: 'currency', sortable: true, initialWidth: 150 },
        { label: 'Expired Value', fieldName: 'expiredValue', type: 'currency', sortable: true, initialWidth: 150 },
        { label: 'Usable Value', fieldName: 'usableValue', type: 'currency', sortable: true, initialWidth: 150 },
        { label: 'Last Usage Date', fieldName: 'lastUsageDate', type: 'date', sortable: true, initialWidth: 200 },
        { label: 'Distributor', fieldName: 'distributor', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Hospital', fieldName: 'hospital', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Stock Stage', fieldName: 'stockStage', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'In Transit Damaged', fieldName: 'inTransitDamaged', type: 'number', sortable: true, initialWidth: 200 },
        { label: 'Restricted', fieldName: 'restricted', type: 'number', sortable: true, initialWidth: 150 }
    ];

    wpliColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Product Name', fieldName: 'ProductName', type: 'text' },
        { label: 'Serial Number', fieldName: 'Serial_Number__c', type: 'text' },
        { label: 'Batch Number', fieldName: 'Batch_Number__c', type: 'text' },
        {
            label: 'Expiry Date',
            fieldName: 'Expiry_Date__c',
            type: 'date-local',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Condition', fieldName: 'Condition__c', type: 'text' }
    ];

    statusOptions = [
        { label: 'Free', value: 'Free' },
        { label: 'Committed', value: 'Committed' },
        { label: 'In Transit', value: 'In Transit' },
        { label: 'Consumed', value: 'Consumed' },
        { label: 'Delivered', value: 'Delivered' },
        { label: 'Material Returned', value: 'Material Returned' }
    ];

    handleWarehouseChange(event) {
        this.selectedWarehouseId = event.detail.value;
        this.isWarehouseSelected = true;
        this.checkVisibility();
        this.fetchInventory();
    }

    handleStatusOptionsChange(event) {
        this.selectedStatus = event.detail.value;
        this.fetchInventory();
    }

    fetchInventory() {
        this.isLoading = true;
        getInventoryData({ warehouseIds: [this.selectedWarehouseId], statusFilter: this.selectedStatus })
            .then(data => {
                this.tableData = data;
                this.showReverseTable = false;
                this.damagedProducts = [];
                this.isProceedDisabled = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error fetching inventory summary:', error);
            });
    }

    conditionOptions = [
        { label: 'All', value: 'All' },
        { label: 'Damaged', value: 'Damaged' },
        { label: 'Wrong Item', value: 'Wrong Item' },
        { label: 'Expired', value: 'Expired' },
        { label: 'Good', value: 'Good' }
    ];

    handleConditionChange(event) {
        console.log('Selected wpliData:', this.wpliData);
        this.selectedCondition = event.detail.value;
        this.isLoading = true;
        if (this.selectedCondition === 'All') {
            this.reverseSOTableData = this.wpliData;
        } else if (this.wpliData && this.wpliData.length > 0) {
            this.reverseSOTableData = this.wpliData.filter(row => row.Condition__c === this.selectedCondition);
        } else {
            this.reverseSOTableData = [];
        }
        this.isLoading = false;
    }
    handleReverseClick() {
        this.showReverseTable = true;
        this.isLoading = true;

        console.log('Selected warehouseId:', this.selectedWarehouseId);
        getWPLIs({ warehouseId: this.selectedWarehouseId })
            .then(result => {
                if (result) {
                    console.log('Result:', result);
                    this.wpliData = result.map(row => ({
                        ...row,
                        ProductName: row.Warehouse__r?.Zydus_Product__r?.Name || ''
                    }));
                    this.reverseSOTableData = this.wpliData;
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching WPLIs:', error);
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to fetch warehouse line items',
                        variant: 'error'
                    })
                );
            });
    }

    handleBackClick() {
        this.showReverseTable = false;
        this.isProceedDisabled = true;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRows = selectedRows;
        this.isProceedDisabled = selectedRows.length === 0;
    }

    handleProceed() {
        this.isLoading = true;
        createReverseSupplyOrders({ selectedWpliIds: this.selectedRows.map(r => r.Id) })
            .then((rsoId) => {

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Reverse Supply Orders created successfully.',
                        variant: 'success'
                    })
                );
                this.isLoading = false;
                this.showReverseTable = false;

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: rsoId,
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.isLoading = false;
                console.error(error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }

    checkVisibility() {
        if (!this.selectedWarehouseId) return;
        shouldRSObtnVisible({ warehouseId: this.selectedWarehouseId })
            .then(result => {
                this.showReverseSOBtn = result;
            })
            .catch(error => {
                this.showReverseSOBtn = false;
            });
    }
}