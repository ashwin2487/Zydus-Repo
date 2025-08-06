import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

// Apex Methods
import getAllBrands from '@salesforce/apex/PurchaseOrderController.getAllBrands';
import getAllZydusProducts from '@salesforce/apex/PurchaseOrderController.getAllZydusProducts';
import getPriceBookEntry from '@salesforce/apex/PurchaseOrderController.getPriceBookEntry';
import addProductsToPO from '@salesforce/apex/PurchaseOrderController.addProductsToPO';

// Fields to fetch from the existing Purchase Order
const PO_FIELDS = [
    'Purchase_Order__c.Name', 'Purchase_Order__c.Account__c', 'Purchase_Order__c.Account__r.Name',
    'Purchase_Order__c.Supplier_Distributor__r.Name', 'Purchase_Order__c.Zydus_Price_Book__c', 'Purchase_Order__c.Zydus_Price_Book__r.Name'
];

const COLUMNS = [
    { label: 'Name', fieldName: 'name', type: 'text', wrapText: true },
    { label: 'Brand', fieldName: 'brand', type: 'text' },
    { label: 'Size', fieldName: 'size', type: 'text' },
];

export default class AddProductToPO extends LightningElement {
    @api recordId;

    // UI State
    isLoading = false;
    isLoadingProducts = false;
    selectedBrand;

    // PO Details
    poName;
    accountId;
    selectedAccountName;
    selectedSupplierName;
    selectedPriceBook;
    selectedPriceBookId;

    // Data for Tables and Selection
    columns = COLUMNS;
    @track brandOptions = [];
    @track productList = []; // Master list from server for a brand
    @track productOptions = []; // Filtered/displayed list for datatable
    @track selectedProducts = []; // Products added to the final list
    @track selectedProductIdsFromDataTable = [];
    @track selectedProductIdsForDataTable = []; // For controlling the datatable's selection

    @wire(getRecord, { recordId: '$recordId', fields: PO_FIELDS })
    wiredPORecord({ error, data }) {
        if (data) {
            const fields = data.fields;
            this.poName = fields.Name?.value;
            this.accountId = fields.Account__c?.value;
            this.selectedAccountName = fields.Account__r?.displayValue;
            this.selectedSupplierName = fields.Supplier_Distributor__r?.displayValue;
            this.selectedPriceBookId = fields.Zydus_Price_Book__c?.value;
            this.selectedPriceBook = fields.Zydus_Price_Book__r?.displayValue;
        } else if (error) {
            this.showToast('Error', 'Failed to fetch Purchase Order details.', 'error');
        }
    }

    connectedCallback() {
        getAllBrands()
            .then(result => {
                this.brandOptions = result.map(brand => ({ label: brand.Name, value: brand.Id }));
            })
            .catch(error => {
                this.showToast('Error Loading Brands', 'Could not retrieve brand list.', 'error');
            });
    }

    // --- GETTERS ---
    get isBrandSelected() { return !!this.selectedBrand; }
    get isSubmitDisabled() { return this.selectedProducts.length === 0 || this.isLoading; }
    get isAddProductsDisabled() { return this.selectedProductIdsFromDataTable.length === 0; }

    // --- EVENT HANDLERS ---
    handleBrandChange(event) {
        this.selectedBrand = event.detail.value;
        this.productOptions = [];
        this.productList = [];
        this.isLoadingProducts = true;

        getAllZydusProducts({ brandId: this.selectedBrand })
            .then(result => {
                this.productList = result.map(p => ({ id: p.Id, name: p.Name, brand: p.Brand__r.Name, size: p.Size__c }));
                this.productOptions = [...this.productList];
            })
            .catch(error => this.showToast('Error Loading Products', 'Could not retrieve products for this brand.', 'error'))
            .finally(() => this.isLoadingProducts = false);
    }

    searchTimer;

    handleSearch(event) {
    clearTimeout(this.searchTimer);

    const searchTerm = event.target.value;

    this.searchTimer = setTimeout(() => {
        if (searchTerm) {
            const lowerCaseSearchTerm = searchTerm.toLowerCase();
            this.productOptions = this.productList.filter(p => 
                p.name.toLowerCase().includes(lowerCaseSearchTerm)
            );
        } else {
            this.productOptions = [...this.productList];
        }
    }, 500);
}

    handleRowSelection(event) {
        this.selectedProductIdsFromDataTable = event.detail.selectedRows.map(row => row.id);
    }

    handleQuantityChange(event) {
        const index = event.target.dataset.index;
        const value = parseInt(event.target.value, 10);
        if (this.selectedProducts[index]) {
            let updatedProducts = JSON.parse(JSON.stringify(this.selectedProducts));
            updatedProducts[index].minOrderQty = value >= 0 ? value : 0;
            this.selectedProducts = updatedProducts;
        }
    }

    handleDeleteProduct(event) {
        const productIdToDelete = event.currentTarget.dataset.id;
        this.selectedProducts = this.selectedProducts
            .filter(item => item.productId !== productIdToDelete)
            .map((item, i) => ({ ...item, serial: i + 1 }));
    }

    // --- ACTION HANDLERS ---
    handleAddSelectedProducts() {
        if (!this.selectedPriceBookId) {
            this.showToast('Missing Price Book', 'PO must have a Pricebook to add products.', 'warning');
            return;
        }

        const newProductIds = this.selectedProductIdsFromDataTable.filter(id => !this.selectedProducts.some(p => p.productId === id));
        if (newProductIds.length === 0) {
            this.showToast('Products Already Added', 'All selected products are already in the list.', 'info');
            return;
        }

        this.isLoading = true;
        getPriceBookEntry({ productIds: newProductIds, priceBookId: this.selectedPriceBookId })
            .then(entries => {
                if (entries && entries.length > 0) {
                    const newProducts = entries.map(entry => ({
                        productId: entry.Zydus_Product__c,
                        productName: entry.Zydus_Product__r.Name || 'Unnamed Product',
                        unitPrice: entry.Unit_Price__c || 0,
                        minOrderQty: entry.Minimum_Order_Quantity_MOQ__c || 1,
                        serial: this.selectedProducts.length + 1
                    }));
                    this.selectedProducts = [...this.selectedProducts, ...newProducts];
                    this.showToast('Success', `${newProducts.length} product(s) added.`, 'success');
                } else {
                    this.showToast('No Price Book Entry', 'None of the selected products have a valid price book entry.', 'warning');
                }
                this.selectedProductIdsForDataTable = [];
                this.selectedProductIdsFromDataTable = [];
            })
            .catch(error => this.showToast('Error', 'An error occurred while fetching product prices.', 'error'))
            .finally(() => this.isLoading = false);
    }

    handleAddProductsToPO() {
        this.isLoading = true;
        const payload = {
            poId: this.recordId,
            accountId: this.accountId,
            selectedPriceBookId: this.selectedPriceBookId,
            selectedProducts: this.selectedProducts
        };

        addProductsToPO({ payload: JSON.stringify(payload) })
            .then(() => {
                this.showToast('Success', 'Products added to Purchase Order successfully.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'An unknown error occurred.', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}