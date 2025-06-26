import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getAllZydusProducts from '@salesforce/apex/PurchaseOrderController.getAllZydusProducts';
import getPriceBookEntry from '@salesforce/apex/PurchaseOrderController.getPriceBookEntry';
import savePriceBookEntry from '@salesforce/apex/PurchaseOrderController.savePriceBookEntry';
import addProductsToPO from '@salesforce/apex/PurchaseOrderController.addProductsToPO';

const FIELDS = [
    'Purchase_Order__c',
    'Purchase_Order__c.Name',
    'Purchase_Order__c.Account__c',
    'Purchase_Order__c.Account__r.Name',
    'Purchase_Order__c.Supplier_Distributor__c',
    'Purchase_Order__c.Supplier_Distributor__r.Name',
    'Purchase_Order__c.Zydus_Price_Book__c',
    'Purchase_Order__c.Zydus_Price_Book__r.Name'
];

export default class AddProductToPO extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track selectedAccountName;
    @track accountId;
    @track selectedSupplierName;
    @track selectedPriceBook;
    @track selectedPriceBookId;
    @track selectedSupplierDistributorId;
    @track poName;
    @track poId;
    @track selectedProducts = [];
    @track showAddProduct = false;
    @track showAddEntryModal = false;
    @track selectedProductId;
    @track selectedProductName;
    @track productOptions = [];
    @track newEntry = { useBrandPricing: true };
    poDetails;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    poRecordHandler({ error, data }) {
        if (data) {
            this.poDetails = data;
            this.setPODetails();
        } else if (error) {
            this.showToast('Error', 'Failed to fetch Purchase Order details', 'error');
        }
    }

    setPODetails() {
        const data = this.poDetails.fields;

        this.selectedAccountName =
            data.Account__r?.displayValue ||
            data.Account__r?.value?.fields?.Name?.value;

        this.accountId = data.Account__c?.value

        this.selectedSupplierName =
            data.Supplier_Distributor__r?.displayValue ||
            data.Supplier_Distributor__r?.value?.fields?.Name?.value;

        this.poName = data.Name?.value;

        this.poId = this.recordId;

        this.selectedPriceBook =
            data.Zydus_Price_Book__r?.displayValue ||
            data.Zydus_Price_Book__r?.value?.fields?.Name?.value;

        this.selectedPriceBookId = data.Zydus_Price_Book__c?.value;
        this.selectedSupplierDistributorId = data.Supplier_Distributor__c?.value;
    }

    connectedCallback() {
        getAllZydusProducts()
            .then(result => {
                if (result) {
                    this.productOptions = result
                        .map(product => ({
                            label: product.Name,
                            value: product.Id
                        }))
                        .sort((a, b) => a.label.localeCompare(b.label));
                } else {
                    this.productOptions = [];
                }
            })
            .catch(error => {
                this.showToast('Error loading products', error.body?.message || error.message, 'error');
            });
    }

    handleProductChange(event) {
        const productId = event.detail.value;
        this.selectedProductId = productId;
        this.selectedProductName = this.productOptions.find(opt => opt.value === productId)?.label;
        this.showAddProduct = false;

        if (!this.selectedPriceBookId) {
            this.toast('Missing Price Book', 'Please select a price book first.', 'warning');
            return;
        }

        if (this.selectedProducts.find(prod => prod.productId === productId)) {
            this.toast('Product Already Added', 'Product is already added to the PO.', 'warning');
            return;
        }

        this.isLoading = true;
        getPriceBookEntry({ productId, priceBookId: this.selectedPriceBookId })
            .then(entry => {
                console.log('Price Book Entry:', entry);
                if (entry) {
                    if (!entry.Is_Active__c) {
                        this.showToast('Inactive Entry', 'This product is currently inactive in the price book. Activate it to add to the PO.', 'warning');
                        return;
                    }

                    const newProduct = {
                        productId: entry.Zydus_Product__c,
                        productName: this.selectedProductName || 'Unnamed Product',
                        unitPrice: entry.Unit_Price__c || 0,
                        mrp: entry.List_Price__c || 0,
                        minOrderQty: entry.Minimum_Order_Quantity_MOQ__c || 0,
                        billDiscount: entry.Bill_Discount_Amount__c || 0,
                        creditNote: entry.Credit_Note_Amount__c || 0,
                        unitTaxablePrice: entry.Unit_Taxable_Price__c || 0,
                        useBrandPricing: entry.Use_Brand_Pricing__c,
                        serial: this.selectedProducts.length + 1
                    };
                    this.selectedProducts = [...this.selectedProducts, newProduct];
                } else {
                    this.showToast('No Entry Found', 'Product not in price book.Add Price Book Entry to add it.', 'info');
                    //this.showAddEntryModal = true;
                }

                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error fetching price book entry:', JSON.stringify(error));
                let msg = error?.body?.message || 'Unknown error occurred';
                this.showToast('Error', msg, 'error');
            });

    }

    handleAddProduct() {
        this.showAddProduct = true;
    }

    handleQuantityChange(event) {
        const index = event.target.dataset.index;
        const value = Number(event.target.value);
        if (index !== undefined && !isNaN(value)) {
            const updated = [...this.selectedProducts];
            updated[index] = { ...updated[index], minOrderQty: value };
            this.selectedProducts = updated;
        }
    }

    handleCheckboxChange(event) {
        this.newEntry.useBrandPricing = event.target.checked;
    }

    handleAddPriceBookEntry() {
        this.showAddEntryModal = false;
        this.showToast('Info', 'Price Book Entry creation not implemented in this example.', 'info');
    }

    handleDeleteProduct(event) {
        const productId = event.currentTarget.dataset.id;
        this.selectedProducts = this.selectedProducts
            .filter(prod => prod.productId !== productId)
            .map((prod, index) => ({ ...prod, serial: index + 1 }));
    }

    toggleInlineForm() {
        this.showAddEntryModal = !this.showAddEntryModal;
    }

    handleSavePriceBookEntry() {
        this.isLoading = true;
        savePriceBookEntry({
            productId: this.selectedProductId,
            priceBookId: this.selectedPriceBookId,
            useBrandPricing: this.newEntry.useBrandPricing
        })
            .then(entry => {
                if (entry) {
                    const newProduct = {
                        productId: entry.Zydus_Product__c,
                        productName: this.selectedProductName || 'Unnamed Product',
                        unitPrice: entry.Unit_Price__c || 0,
                        mrp: entry.List_Price__c || 0,
                        minOrderQty: entry.Minimum_Order_Quantity_MOQ__c || 0,
                        billDiscount: entry.Bill_Discount_Amount__c || 0,
                        creditNote: entry.Credit_Note_Amount__c || 0,
                        unitTaxablePrice: entry.Unit_Taxable_Price__c || 0,
                        useBrandPricing: entry.Use_Brand_Pricing__c
                    };
                    this.selectedProducts = [...this.selectedProducts, newProduct];
                    this.showToast('Success', 'Price book entry saved and product added successfully.', 'success');
                }
                this.showAddEntryModal = false;
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Unknown error', 'error');
                this.showAddEntryModal = false;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    get isAddDisabled() {
        return this.selectedProducts.length === 0;
    }

    handleAddProductsToPO() {
        const payload = {
            accountId:this.accountId,
            poId: this.poId,
            selectedPriceBookId: this.selectedPriceBookId,
            selectedProducts: this.selectedProducts
        };

        addProductsToPO({ payload: JSON.stringify(payload) })
            .then(result => {
                this.showToast('Success', 'Products added to Purchase Order successfully', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                console.error('Error adding products to PO:', error);
                this.showToast('Error', error.body?.message || error.message || 'Unknown error', 'error');
            });
    }

}