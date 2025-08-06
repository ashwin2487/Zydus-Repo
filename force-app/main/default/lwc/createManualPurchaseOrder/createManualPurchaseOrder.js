import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllZydusProducts from '@salesforce/apex/PurchaseOrderController.getAllZydusProducts';
import latestPOName from '@salesforce/apex/PurchaseOrderController.latestPOName';
import getPriceBookEntry from '@salesforce/apex/PurchaseOrderController.getPriceBookEntry';
import getCurrentAccountDetails from '@salesforce/apex/PurchaseOrderController.getCurrentAccountDetails'
import { NavigationMixin } from 'lightning/navigation';
import createManualPurchaseOrder from '@salesforce/apex/PurchaseOrderController.createManualPurchaseOrder';
import getAllBrands from '@salesforce/apex/PurchaseOrderController.getAllBrands';


export default class CreateManualPurchaseOrder extends NavigationMixin(LightningElement) {
    @track selectedProductIds;
    @track accountId;
    @track selectedAccountName;
    @track selectedSupplierDistributorId;
    @track selectedSupplierName;
    @track poName;
    @track selectedPriceBook;
    @track productOptions = [];
    @track selectedProducts = [];
    @track productList = [];
    @track isLoading = false;
    showAddEntryButton = false;
    showAddProduct = false;
    showAddEntryModal = false;
    @track newEntry = { useBrandPricing: true };
    @track selectedProductName;
    accountDetails;
    approvePurchaseOrder = false;
    @track selectedBrand;
    brandOptions = [];
    isLoadingProducts = false;
    columns = [
        { label: 'Name', fieldName: 'name', type: 'text' },
        { label: 'Brand', fieldName: 'brand', type: 'text' },
        { label: 'Size', fieldName: 'size', type: 'text' },
    ];
    productOptionsEmpty = [];
    @track manualPOLable = 'Create Manual Purchase Order';
    @track disableCreatePOBtn;

    @wire(getCurrentAccountDetails)
    wiredAccount({ data, error }) {
        if (data) {
            console.log('DATA:',data);
            this.accountId = data.Id;
            this.selectedAccountName = data.Name;
            this.selectedSupplierDistributorId = data.ParentId;
            this.selectedSupplierName = data.Parent?.Name;
            this.selectedPriceBookId = data.Zydus_Price_Book__c;
            this.selectedPriceBook = data.Zydus_Price_Book__r?.Name;
        } else if (error) {
            console.error('Error loading account:', error);
        }
    }

    get hasData() {
        return this.productList && this.productList.length > 0;
    }

    get columnCount() {
        return this.columns.length;
    }
    connectedCallback() {
        getAllBrands().then(result => {
            if (result) {
                this.brandOptions = result.map(brand => ({
                    label: brand.Name,
                    value: brand.Id
                }));
            } else {
                this.brandOptions = [];
            }
        }).catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading brands',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }

    handleBrandChange(event) {
        this.selectedBrand = event.detail.value;
        this.isLoadingProducts = true;
        getAllZydusProducts({ brandId: this.selectedBrand })
            .then(result => {
                if (result) {
                    this.productList = result;
                    this.productOptions = result.map(product => ({
                        id: product.Id,
                        name: product.Name,
                        brand: product.Brand__r.Name,
                        size: product.Size__c,
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
            }).finally(() => {
                this.isLoadingProducts = false;
            });
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        const selectedIds = selectedRows.map(row => row.id);
        this.selectedProductIds = selectedIds;

    }

    handleAddProduct() {

        if (!this.selectedPriceBookId) {
            this.toast('Missing Price Book', 'Please select a price book first.', 'warning');
            return;
        }
        const duplicateProducts = this.selectedProducts.filter(prod =>
            this.selectedProductIds.includes(prod.productId)
        );

        if (duplicateProducts.length > 0) {
            const duplicateNames = duplicateProducts.map(p => p.productName).join(', ');
            this.toast('Product Already Added',
                `The following products are already in the PO: ${duplicateNames}`,
                'warning'
            );
            return;
        }

        this.isLoading = true;
        getPriceBookEntry({ productIds: this.selectedProductIds, priceBookId: this.selectedPriceBookId })
            .then(entries => {
                console.log('Price Book Entries:', entries);

                if (entries && entries.length > 0) {
                    const newProducts = [];

                    entries.forEach(entry => {
                        if (!entry.Is_Active__c) {
                            this.toast('Inactive Entry', `Product is inactive in the price book.`, 'warning');
                            return;
                        }

                        const newProduct = {
                            productId: entry.Zydus_Product__c,
                            productName: entry.Zydus_Product__r.Name || 'Unnamed Product',
                            size: entry.Zydus_Product__r.Size__c || 'N/A',
                            unitPrice: entry.Unit_Price__c || 0,
                            mrp: entry.Zydus_Product__r.MRP__c || 0,
                            minOrderQty: entry.Minimum_Order_Quantity_MOQ__c || 0,
                            billDiscount: entry.Bill_Discount_Amount__c || 0,
                            creditNote: entry.Credit_Note_Amount__c || 0,
                            unitTaxablePrice: entry.Unit_Taxable_Price__c || 0,
                            useBrandPricing: entry.Use_Brand_Pricing__c,
                            serial: this.selectedProducts.length + newProducts.length + 1
                        };
                        newProducts.push(newProduct);
                    });

                    // Add all the newly created products to the main list at once
                    this.selectedProducts = [...this.selectedProducts, ...newProducts];

                } else {
                    // This block now correctly executes only if no entries are found for any of the products
                    this.toast('No Entry Found', 'Product not in price book. Add Price Book Entry to add it.', 'info');
                }
                this.selectedProductIds = [];

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

    get disableCreatePOBtnGetter() {
        return this.disableCreatePOBtn || this.selectedProducts.length === 0;
    }

    handleCheckboxChange(event) {
        this.newEntry.useBrandPricing = event.target.checked;
    }

    // handleSavePriceBookEntry() {
    //     savePriceBookEntry({
    //         productId: this.selectedProductId,
    //         priceBookId: this.selectedPriceBookId,
    //         useBrandPricing: this.newEntry.useBrandPricing
    //     }).then(entry => {
    //         console.log('ENTRY', entry);
    //         if (entry) {
    //             const newProduct = {
    //                 pricebookEntryId: entry.Id,
    //                 productId: entry.Zydus_Product__c,
    //                 productName: this.selectedProductName || 'Unnamed Product',
    //                 unitPrice: entry.Unit_Price__c || 0,
    //                 listPrice: entry.List_Price__c || 0,
    //                 mrp: entry.List_Price__c || 0,
    //                 minOrderQty: entry.Minimum_Order_Quantity_MOQ__c || 0,
    //                 billDiscount: entry.Bill_Discount_Amount__c || 0,
    //                 creditNote: entry.Credit_Note_Amount__c || 0,
    //                 useBrandPricing: entry.Use_Brand_Pricing__c
    //             };
    //             this.selectedProducts = [...this.selectedProducts, newProduct];
    //         }
    //         this.showAddEntryModal = false;
    //         this.showAddEntryButton = false;
    //         this.toast('Success', 'Price book entry saved and product added successfully.', 'success');
    //     })
    //         .catch(error => {
    //             this.showAddEntryModal = false;
    //             this.showAddEntryButton = false;
    //             this.toast('Error', error.body?.message || 'Unknown error', 'error');
    //         });
    // }

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
    handleApproveChange(event) {
        this.approvePurchaseOrder = event.target.checked;
    }
    async handleCreateManualPO() {

        const payload = {
            accountId: this.accountId,
            supplierId: this.selectedSupplierDistributorId,
            poName: await latestPOName({ accountId: this.accountId }),
            priceBookId: this.selectedPriceBookId,
            products: this.selectedProducts,
            approvePurchaseOrder: this.approvePurchaseOrder
        }
        this.manualPOLable = 'Processing Purchase Order...';
        this.disableCreatePOBtn = true;
        await createManualPurchaseOrder({ payload: JSON.stringify(payload) })
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

    searchTimeout;

    handleSearch(event) {
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        const searchProduct = event.target.value;

        this.searchTimeout = setTimeout(() => {
            const searchTerm = searchProduct.toLowerCase();

            if (searchTerm) {
                const filteredProducts = this.productList.filter(product =>
                    product.Name.toLowerCase().includes(searchTerm)
                );

                this.productOptions = filteredProducts.map(product => ({
                    id: product.Id,
                    name: product.Name,
                    brand: product.Brand__r.Name,
                    size: product.Size__c,
                }));
            } else {
                this.productOptions = this.productList.map(product => ({
                    id: product.Id,
                    name: product.Name,
                    brand: product.Brand__r.Name,
                    size: product.Size__c,
                }));
            }
        }, 300);
    }
}