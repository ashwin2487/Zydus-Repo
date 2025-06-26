import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllZydusProducts from '@salesforce/apex/PurchaseOrderController.getAllZydusProducts';
import latestPOName from '@salesforce/apex/PurchaseOrderController.latestPOName';
import getPriceBookEntry from '@salesforce/apex/PurchaseOrderController.getPriceBookEntry';
import savePriceBookEntry from '@salesforce/apex/PurchaseOrderController.savePriceBookEntry';
import { wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import createManualPurchaseOrder from '@salesforce/apex/PurchaseOrderController.createManualPurchaseOrder';


export default class CreateManualPurchaseOrder extends NavigationMixin(LightningElement) {
    @track selectedProductId;
    @api recordId;
    @track selectedAccountName;
    @track selectedSupplierDistributorId;
    @track selectedSupplierName;
    @track poName;
    @track selectedPriceBook;
    @track productOptions = [];
    @track selectedProducts = [];
    @track isLoading = false;
    showAddEntryButton = false;
    showAddProduct = false;
    showAddEntryModal = false;
    @track newEntry = { useBrandPricing: true };
    @track selectedProductName;
    accountDetails;


    @wire(getRecord, { recordId: '$recordId', fields: ['Account.Id', 'Account.Name', 'Account.ParentId', 'Account.Parent.Name', 'Account.Zydus_Price_Book__c', 'Account.Zydus_Price_Book__r.Name'] })
    account({ error, data }) {
        if (data) {
            this.accountDetails = data;
            this.setAccountDetails();
        } else if (error) {
            this.toast('Error', error.body.message, 'error');
        }
    }

    setAccountDetails() {
        const accFields = this.accountDetails.fields;
        this.selectedAccountName = accFields.Name.value;
        this.selectedSupplierDistributorId = accFields.ParentId?.value;
        this.selectedSupplierName = accFields.Parent?.displayValue;
        this.selectedPriceBookId = accFields.Zydus_Price_Book__c?.value;
        this.selectedPriceBook = accFields.Zydus_Price_Book__r?.displayValue;
    }

    connectedCallback() {
        
        getAllZydusProducts()
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

    handleAddProduct() {
        this.showAddProduct = true;
        this.showAddEntryButton = false;
        this.selectedProductId = null;
        this.selectedProductName = null;
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
                        this.toast('Inactive Entry', 'This product is currently inactive in the price book. Activate it to add to the PO.', 'warning');
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
                    this.toast('No Entry Found', 'Product not in price book. Add Price Book Entry to add it.', 'info');
                    //this.showAddEntryButton = true;
                }

                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error fetching price book entry:', JSON.stringify(error));
                let msg = error?.body?.message || 'Unknown error occurred';
                this.toast('Error', msg, 'error');
            });

    }

    handleQuantityChange(event) {
        const index = event.target.dataset.index;
        const value = event.target.value;
        this.selectedProducts[index].minOrderQty = value;
        this.selectedProducts = [...this.selectedProducts];
    }
    handleAddPriceBookEntry() {
        this.showAddEntryModal = true;
    }
    toggleInlineForm() {
        this.showAddEntryModal = !this.showAddEntryModal;
    }

    get disableCreatePOBtn(){
        return this.selectedProducts.length === 0;
    }

    handleCheckboxChange(event) {
        this.newEntry.useBrandPricing = event.target.checked;
    }

    handleSavePriceBookEntry() {
        savePriceBookEntry({
            productId: this.selectedProductId,
            priceBookId: this.selectedPriceBookId,
            useBrandPricing: this.newEntry.useBrandPricing
        }).then(entry => {
            console.log('ENTRY', entry);
            if (entry) {
                const newProduct = {
                    pricebookEntryId: entry.Id,
                    productId: entry.Zydus_Product__c,
                    productName: this.selectedProductName || 'Unnamed Product',
                    unitPrice: entry.Unit_Price__c || 0,
                    listPrice : entry.List_Price__c || 0,
                    mrp: entry.List_Price__c || 0,
                    minOrderQty: entry.Minimum_Order_Quantity_MOQ__c || 0,
                    billDiscount: entry.Bill_Discount_Amount__c || 0,
                    creditNote: entry.Credit_Note_Amount__c || 0,
                    useBrandPricing: entry.Use_Brand_Pricing__c
                };
                this.selectedProducts = [...this.selectedProducts, newProduct];
            }
            this.showAddEntryModal = false;
            this.showAddEntryButton = false;
            this.toast('Success', 'Price book entry saved and product added successfully.', 'success');
        })
            .catch(error => {
                this.showAddEntryModal = false;
                this.showAddEntryButton = false;
                this.toast('Error', error.body?.message || 'Unknown error', 'error');
            });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    handleDeleteProduct(event) {
        const productId = event.currentTarget.dataset.id;
        this.selectedProducts = this.selectedProducts.filter(item => item.productId !== productId);

        this.selectedProducts = this.selectedProducts.map((item, i) => ({
            ...item,
            serial: i + 1
        }));
    }

    async handleCreateManualPO() {
        const payload = {
            accountId: this.recordId,
            supplierId: this.selectedSupplierDistributorId,
            poName: await latestPOName({ accountId: this.recordId }),
            priceBookId: this.selectedPriceBookId,
            products: this.selectedProducts
        }

        createManualPurchaseOrder({ payload: JSON.stringify(payload) })
            .then(Id => {
                console.log('RESULT', Id);
                this.toast('Success', 'Purchase Order Created Successfully', 'success');

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: Id,
                        objectApiName: 'Purchase_Order__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                console.log('ERROR', error);
                this.toast('Error', error.body?.message || error.message || 'Unknown error', 'error');
            });
    }
}