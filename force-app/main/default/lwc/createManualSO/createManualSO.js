import { LightningElement, wire, api, track } from 'lwc';
import getConsigneeDistributor from '@salesforce/apex/SupplyOrderController.getConsigneeDistributor';
import getProductByPB from '@salesforce/apex/SupplyOrderController.getProductByPB';
import getWarehouseLineItem from '@salesforce/apex/SupplyOrderController.getWarehouseLineItem';
import getProductForConsignee from '@salesforce/apex/SupplyOrderController.getProductForConsignee';
import getAccountDetails from '@salesforce/apex/SupplyOrderController.getAccountDetails';
import getConsigneePB from '@salesforce/apex/SupplyOrderController.getConsigneePB';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createSupplyOrderWithLineItems from '@salesforce/apex/SupplyOrderController.createSupplyOrderWithLineItems';
import { CloseActionScreenEvent } from "lightning/actions";
const SERIAL_NUMBER_LENGTH = 15;
export default class CreateManualSO extends NavigationMixin(LightningElement) {

    @track accountId;
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
    isLoadingProducts = false;
    @track manualSOLable = 'Create Manual Sales Order';
    disableCreateSOBtn = false;
    columns = [
        { label: 'Name', fieldName: 'Name', sortable: true, type: 'text', initialWidth: 100 },
        { label: 'Product Name', fieldName: 'ZydusProduct', type: 'text', sortable: true, initialWidth: 150 },
        { label: 'Warehouse', fieldName: 'WarehouseName', sortable: true, initialWidth: 250 },
        { label: 'Serial Number', fieldName: 'Serial_Number__c', sortable: true, initialWidth: 150 },
        { label: 'Batch Number', fieldName: 'Batch_Number__c', sortable: true, initialWidth: 150 },
        { label: 'HSN Code', fieldName: 'hsnCode', sortable: true, initialWidth: 150 },
        { label: 'Status', fieldName: 'Status__c', sortable: true, initialWidth: 100 },
        { label: 'Condition', fieldName: 'Condition__c', sortable: true, initialWidth: 100 },
        { label: 'Expiry Date', fieldName: 'Expiry_Date__c', type: 'date', sortable: true, initialWidth: 150 },
        { label: 'Manufactured Date', fieldName: 'Manufactured_Date__c', type: 'date', sortable: true, initialWidth: 150 },
        { label: 'Unit Price', fieldName: 'Unit_Price__c', type: 'currency', sortable: true, initialWidth: 100 }
    ];


    @wire(getAccountDetails)
    account({ error, data }) {
        if (data) {
            console.log('RESULT:', data);
            this.accountId = data.Id;
            this.selectedSupplierName = data.Name;
        } else if (error) {
            this.toast('Error', error.body.message, 'error');
        }
    }

    async handleConsigneeDistributorChange(event) {
        this.consigneeDistributor = event.detail.value;
        this.isLoadingProducts = true; 
        this.validSelectedProducts=[];
        try {
            const [
                consigneeProducts,
                pricebook
            ] = await Promise.all([
                getProductForConsignee({ consigneeId: this.consigneeDistributor }),
                getConsigneePB({ consigneeId: this.consigneeDistributor })
            ]);
            this.consigneeDistributorProductIds = Array.isArray(consigneeProducts) ? consigneeProducts.map(product => product.Id) : [];
            if (pricebook) {
                this.selectedPriceBookId = pricebook.Id;
                this.selectedPriceBook = pricebook.Name;
                const products = await getProductByPB({ PBId: this.selectedPriceBookId });
                this.productOptions = products ? products.map(product => ({
                    label: product.Name,
                    value: product.Id
                })) : [];
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoadingProducts = false;
        }
    }


    get showWarehouseLineItemTable() {
        return !!this.consigneeDistributor;
    }

    @wire(getConsigneeDistributor, { Id: '$accountId' })
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

        const removedProduct = this.validSelectedProducts.find(p => p.Id === productIdToRemove);

        this.validSelectedProducts = this.validSelectedProducts.filter(p => p.Id !== productIdToRemove);

        if (removedProduct) {
            this.sortedData = [...this.sortedData, removedProduct];
        }
    }


    get disableAddProductBtn() {
        return this.selectedRows.length === 0;
    }

    @track warehouseLineItems = [];

    @wire(getWarehouseLineItem, { Id: '$accountId' })
    wiredLineItems({ error, data }) {
        if (data) {
            this.warehouseLineItems = data.map(item => ({
                ...item,
                ZydusProduct: item.Warehouse__r?.Zydus_Product__r.Name || '',
                WarehouseName: item.Connected_Warehouse__r.Name || 'N/A',
                hsnCode: item.Warehouse__r?.Zydus_Product__r.HSN_Code__r.Name || 'N/A',
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

    get disableCreateSOBtnGetter() {
        return this.disableCreateSOBtn || this.validSelectedProducts.length === 0;
    }

    handleCreateManualSO() {
        console.log('PAYLOAD:', this.validSelectedProducts);

        const dtoList = this.validSelectedProducts.map(item => ({
            name: item.Name,
            hsnCode: item.Warehouse__r?.Zydus_Product__r?.HSN_Code__c || '',
            warehouseId: item.Connectec_Warehouse__c,
            serialNumber: item.Serial_Number__c,
            batchNumber: item.Batch_Number__c,
            manufacturedDate: item.Manufactured_Date__c,
            expiryDate: item.Expiry_Date__c,
            lineItemId: item.Id,
            unitPrice: item.Unit_Price__c || 0,
            taxMaster: item.Warehouse__r.Zydus_Product__r.Tax_Master__c || null,
            zydusProductId: item.Warehouse__r?.Zydus_Product__c || null
        }));
        this.disableCreateSOBtn = true;
        this.manualSOLable = 'Creating Manual Sales Order...';

        console.log('dtoList: ', dtoList);
        createSupplyOrderWithLineItems({
            consigneeId: this.consigneeDistributor,
            consignorId: this.accountId,
            warehouseItemsJson: JSON.stringify(dtoList)
        })
            .then(soId => {
                console.log('soId: ', soId);
                this.showToast('Success', 'Supply Order created successfully', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());

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
                this.showToast('Error', error?.body?.message || error?.message, 'error');
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

    @track bulkSerialInput = ''
    get bulkScanPlaceholder() {
        return `Enter/Scan ${SERIAL_NUMBER_LENGTH} Serial Numbers`;
    }
    handleBulkSerialChange(event) {
        const serial = event.target.value;
        if (serial && serial.length === SERIAL_NUMBER_LENGTH) {
            const matchingProduct = this.sortedData.find(item =>
                item.Serial_Number__c === serial
            );

            if (matchingProduct) {
                const productId = matchingProduct?.Warehouse__r?.Zydus_Product__c;
                if (!this.consigneeDistributorProductIds.includes(productId)) {
                    const productName = matchingProduct.ZydusProduct || matchingProduct?.Warehouse__r?.Zydus_Product__r?.Name || 'Unknown Product';
                    this.showToast(
                        'Unavailable Product',
                        `Product ${productName} (${serial}) is not available for this consignee.`,
                        'error'
                    );
                    event.target.value = ''; // Clear input for next scan
                    return;
                }

                const isAlreadyAdded = this.validSelectedProducts.some(p => p.Id === matchingProduct.Id);
                if (isAlreadyAdded) {
                    this.showToast('Duplicate Product', 'This product has already been added.', 'warning');
                    event.target.value = ''; // Clear input
                    return;
                }
                this.validSelectedProducts = [...this.validSelectedProducts, matchingProduct];
                this.sortedData = this.sortedData.filter(p => p.Id !== matchingProduct.Id);
                event.target.value = '';
                this.showToast('Success', `${serial} added successfully.`, 'success');

            } else {
                this.showToast('Error', 'Serial number not found in the available list.', 'error');
                event.target.value = '';
            }
        }
    }
}