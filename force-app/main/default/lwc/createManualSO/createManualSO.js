import { LightningElement, wire, api, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getConsigneeDistributor from '@salesforce/apex/SupplyOrderController.getConsigneeDistributor';
import getProductByPB from '@salesforce/apex/SupplyOrderController.getProductByPB';
import getWarehouseLineItem from '@salesforce/apex/SupplyOrderController.getWarehouseLineItem';
import getProductForConsignee from '@salesforce/apex/SupplyOrderController.getProductForConsignee';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createSupplyOrderWithLineItems from '@salesforce/apex/SupplyOrderController.createSupplyOrderWithLineItems';

export default class CreateManualSO extends NavigationMixin(LightningElement) {

    @api recordId;
    @track selectedAccountName;
    @track selectedSupplierName;
    @track selectedPriceBookId;
    @track selectedPriceBook;
    @track soName;
    @track consigneeDistributor;
    @track consigneeDistributorOptions = [];
    @track selectedProductId;
    @track selectedRows = [];
    @track sortedData = [];
    @track sortBy;
    @track sortDirection;
    consigneeDistributorProductIds = [];
    @track validSelectedProducts = [];

    columns = [
        { label: 'Name', fieldName: 'Name', sortable: true, type: 'text', initialWidth: 100 },
        { label: 'Product Name', fieldName: 'ZydusProduct', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Connected Warehouse', fieldName: 'WarehouseName', sortable: true, initialWidth: 250 },
        { label: 'Serial Number', fieldName: 'Serial_Number__c', sortable: true, initialWidth: 150 },
        { label: 'Batch Number', fieldName: 'Batch_Number__c', sortable: true, initialWidth: 150 },
        { label: 'Status', fieldName: 'Status__c', sortable: true, initialWidth: 100 },
        { label: 'Condition', fieldName: 'Condition__c', sortable: true, initialWidth: 100 },
        { label: 'Expiry Date', fieldName: 'Expiry_Date__c', type: 'date', sortable: true, initialWidth: 150 },
        { label: 'Is Expired?', fieldName: 'Is_Expired__c', type: 'boolean', sortable: true, initialWidth: 100 },
        { label: 'Manufactured Date', fieldName: 'Manufactured_Date__c', type: 'date', sortable: true, initialWidth: 150 },
        { label: 'Unit Price', fieldName: 'Unit_Price__c', type: 'currency', sortable: true, initialWidth: 100 }
    ];


    @wire(getRecord, { recordId: '$recordId', fields: ['Account.Id', 'Account.Name', 'Account.Zydus_Price_Book__c', 'Account.Zydus_Price_Book__r.Name'] })
    account({ error, data }) {
        if (data) {
            this.accountDetails = data;
            console.log('accountDetails:', this.accountDetails);
            this.setAccountDetails();
        } else if (error) {
            this.toast('Error', error.body.message, 'error');
        }
    }

    setAccountDetails() {
        const accFields = this.accountDetails.fields;
        this.selectedSupplierName = accFields.Name.value;
        this.selectedPriceBookId = accFields.Zydus_Price_Book__c?.value;
        this.selectedPriceBook = accFields.Zydus_Price_Book__r?.displayValue;

        getProductByPB({ PBId: this.selectedPriceBookId })
            .then(result => {
                if (result) {
                    this.productOptions = result.map(product => ({
                        label: product.Name,
                        value: product.Id
                    }));
                } else {
                    this.productOptions = [];
                }
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading products',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            }
            );

    }

    handleConsigneeDistributorChange(event) {
        try {
            this.consigneeDistributor = event.detail.value;

            getProductForConsignee({ consigneeId: this.consigneeDistributor })
                .then(result => {
                    console.log('RESULT:', result);
                    if (result && Array.isArray(result)) {
                        this.consigneeDistributorProductIds = result.map(product => product.Id);
                    } else {
                        this.consigneeDistributorProductIds = [];
                    }
                    this.isProductListLoaded = true;
                })
                .catch(error => {
                    console.error('Apex call failed:', error);
                    this.isProductListLoaded = true;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error loading products',
                            message: error.body?.message || error.message || 'Unknown error',
                            variant: 'error'
                        })
                    );
                });
        } catch (e) {
            console.error('Error in handleCongneeDistributorChange:', e);
        }
    }


    get showWarehouseLineItemTable() {
        return !!this.consigneeDistributor;
    }


    @wire(getConsigneeDistributor, { Id: '$recordId' })
    wiredConsigneeDistributor({ error, data }) {
        if (data) {
            this.consigneeDistributorOptions = data.map(acc => ({
                label: acc.Name,
                value: acc.Id
            }));
        } else if (error) {
            console.error('Error: ', error);
        }
    }

    handleAddProduct() {
        console.log('add product triggered');

        const validProducts = [];
        const unavailableProducts = [];

        this.selectedRows.forEach(row => {
            const productId = row?.Warehouse__r?.Zydus_Product__c;

            if (this.consigneeDistributorProductIds.includes(productId)) {
                validProducts.push(row);
            } else {
                unavailableProducts.push({
                    productName: row.ZydusProduct || row?.Warehouse__r?.Zydus_Product__r?.Name || 'Unknown Product',
                    serialNumber: row.Serial_Number__c
                });
            }
        });

        console.log('unavailableProducts: ', unavailableProducts);

        if (unavailableProducts.length > 0) {
            const names = unavailableProducts.map(p => `${p.productName} (${p.serialNumber})`).join(', ');
            this.showToast('Unavailable Products', `These products are not available for this consignee: ${names}`, 'error');
        }

        const existingIds = new Set(this.validSelectedProducts.map(p => p.Id));
        const newValidProducts = validProducts.filter(p => !existingIds.has(p.Id));
        this.validSelectedProducts = [...this.validSelectedProducts, ...newValidProducts];

        const validIds = new Set(validProducts.map(p => p.Id));
        this.sortedData = this.sortedData.filter(p => !validIds.has(p.Id));
    }


    removeSelectedProduct(event) {
        const productIdToRemove = event.currentTarget.dataset.id;
        this.validSelectedProducts = this.validSelectedProducts.filter(p => p.Id !== productIdToRemove);
    }

    get disableAddProductBtn() {
        return this.selectedRows.length === 0;
    }


    @track warehouseLineItems = [];

    @wire(getWarehouseLineItem, { Id: '$recordId' })
    wiredLineItems({ error, data }) {
        if (data) {
            this.warehouseLineItems = data.map(item => ({
                ...item,
                ZydusProduct: item.Warehouse__r?.Zydus_Product__r.Name || '',
                WarehouseName: item.Connected_Warehouse__r.Name || 'N/A'
            }));
            this.sortedData = [...this.warehouseLineItems];
        } else if (error) {
            console.error('Error loading warehouse items:', error);
        }
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
        console.log('Selected rows:', this.selectedRows);
    }

    handleSort(event) {
        const { fieldName: sortBy, sortDirection } = event.detail;
        const cloneData = [...this.sortedData];

        cloneData.sort(this.sortByField(sortBy, sortDirection));

        this.sortedData = cloneData;
        this.sortBy = sortBy;
        this.sortDirection = sortDirection;
    }
    sortByField(field, direction = 'asc') {
        return (a, b) => {
            let aVal = a[field] ?? '';
            let bVal = b[field] ?? '';

            if (typeof aVal === 'string') aVal = aVal.toLowerCase();
            if (typeof bVal === 'string') bVal = bVal.toLowerCase();

            let result = 0;
            if (aVal > bVal) {
                result = 1;
            } else if (aVal < bVal) {
                result = -1;
            }

            return direction === 'asc' ? result : -result;
        };
    }

    get disableCreateSOBtn() {
        return this.validSelectedProducts.length === 0;
    }

    handleCreateManualSO() {
        console.log('PAYLOAD:', this.validSelectedProducts);

        const dtoList = this.validSelectedProducts.map(item => ({
            name: item.Name,
            warehouseId: item.Warehouse__c,
            serialNumber: item.Serial_Number__c,
            batchNumber: item.Batch_Number__c,
            manufacturedDate: item.Manufactured_Date__c,
            expiryDate: item.Expiry_Date__c,
            lineItemId: item.Id,
            unitPrice: item.Unit_Price__c || 0,            
            taxMaster:item.Warehouse__r.Zydus_Product__r.Tax_Master__c || null,
            zydusProductId: item.Warehouse__r?.Zydus_Product__c || null
        }));

        console.log('dtoList: ',dtoList);
        createSupplyOrderWithLineItems({
            consigneeId: this.consigneeDistributor,
            consignorId: this.recordId,
            warehouseItemsJson:JSON.stringify(dtoList)
        })
            .then(soId => {
                this.showToast('Success', 'Supply Order created successfully', 'success');
                // Navigate or reset component
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: soId,
                        objectApiName: 'Supply_Order__c',
                        actionName: 'view'
                    }
                });

            })
            .catch(error => {
            })

    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(evt);
    }

}