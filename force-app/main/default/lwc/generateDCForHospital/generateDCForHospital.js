import { LightningElement, track, api } from 'lwc';
import getHospitals from '@salesforce/apex/GenerateDeliveryChallan.getHospitals';
import getWarehouses from '@salesforce/apex/GenerateDeliveryChallan.getWarehouses';
import getLatestDCNumber from '@salesforce/apex/GenerateDeliveryChallan.getLatestDCNumber';
import getConsignorName from '@salesforce/apex/GenerateDeliveryChallan.getConsignorName';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createDCForHospital from '@salesforce/apex/GenerateDeliveryChallan.createDCForHospital';
import getWarehouseLineItems from '@salesforce/apex/GenerateDeliveryChallan.getWarehouseLineItems';
import getProducts from '@salesforce/apex/GenerateDeliveryChallan.getProducts';
import { NavigationMixin } from 'lightning/navigation';


export default class GenerateDCForHospital extends NavigationMixin(LightningElement) {
    @track consigneeHospital;
    @track hospitalOptions = [];
    @track warehouseOptions = [];
    @track products = [];
    @track deliveryChallanNumber = 'DC-HOSP-0001';
    @track consignorDistributor = '';
    @track consignorDistributorId;

    @track isModalOpen = false;
    @track currentProduct = { product: '', warehouse: '' };
    @track modalTitle = '';
    @track modalActionLabel = '';
    @track productOptions = [];
    editKey = null;
    rowKey = 0;
    @track warehouseLineItems = [];
    @track selectedRows = [];
    @track selectedRowKeys = [];
    @track selectedRowsData = [];
    @track showHospDCPage = true;
    @track message = '';
    @track consigneeHospitalName = '';

    lineItemsColumn = [
        { label: 'Batch Number', fieldName: 'Batch_Number__c' },
        { label: 'Serial Number', fieldName: 'Serial_Number__c' },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Condition', fieldName: 'Condition__c' },
        { label: 'Manufactured Date', fieldName: 'Manufactured_Date__c', type: 'date' },
        { label: 'Expiry Date', fieldName: 'Expiry_Date__c', type: 'date' },
    ];

    connectedCallback() {
        this.loadHospitals();
        this.loadWarehouses();
        this.getConsignor();
    }

    loadHospitals() {
        getHospitals()
            .then(result => {
                this.hospitalOptions = result.map(h => ({ label: h.Name, value: h.Id }));
            })
            .catch(error => console.error(error));
    }

    loadWarehouses() {
        getWarehouses()
            .then(result => {
                this.warehouseOptions = result.map(w => ({ label: w.Name, value: w.Id }));
            })
            .catch(error => console.error(error));
    }

    getConsignor() {
        getConsignorName()
            .then(result => {
                if (result.length) {
                    this.consignorDistributor = result[0].Name;
                    this.consignorDistributorId = result[0].Id;
                }
            })
            .catch(error => console.error(error));
    }

    handleHospitalChange(event) {
        this.consigneeHospital = event.detail.value;

        const hospital = this.hospitalOptions.find(h => h.value === this.consigneeHospital);
        this.consigneeHospitalName = hospital ? hospital.label : 'Unknown Hospital';

        getProducts({ hospitalId: this.consigneeHospital })
            .then(data => {
                this.productOptions = data.map(p => ({ label: p.Zydus_Product__r.Name, value: p.Zydus_Product__c }));
            })
            .catch(error => console.error(error));
        this.generateNextDCNumber();
    }

    handleAddProduct() {
        if (!this.consigneeHospital) {
            this.showToast('Error', 'Please select hospital', 'error');
            return;
        }
        this.warehouseLineItems = [];
        this.editKey = null;
        this.currentProduct = { product: '', warehouse: '' };
        this.modalTitle = 'Add Product';
        this.modalActionLabel = 'Add';
        this.isModalOpen = true;
    }

    handleEditProduct(event) {
        const key = parseInt(event.target.dataset.index, 10);
        const prod = this.products.find(p => p.key === key);
        this.editKey = key;
        // set product id and warehouse id based on existing entry
        this.currentProduct = { product: prod.productId, warehouse: prod.warehouse };
        this.modalTitle = 'Edit Product';
        this.modalActionLabel = 'Update';
        this.isModalOpen = true;
    }

    removeProductRow(event) {
        const key = parseInt(event.target.dataset.index, 10);
        this.products = this.products.filter(p => p.key !== key);
    }

    handleModalFieldChange(event) {
        const { name, value } = event.target;
        this.currentProduct[name] = value;
        if (this.currentProduct.product && this.currentProduct.warehouse) {
            this.loadWarehouseLineItems(this.currentProduct.product, this.currentProduct.warehouse);
        }
    }

    loadWarehouseLineItems(productId, warehouseId) {
        getWarehouseLineItems({ productId, warehouseId })
            .then(data => {
                this.warehouseLineItems = data;
            })
            .catch(error => console.error(error));
    }

    saveProduct() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((v, cmp) => { cmp.reportValidity(); return v && cmp.checkValidity(); }, true);
        if (!allValid) return;

        const qty = this.selectedRowKeys.length;
        if (qty == 0) {
            this.showToast('Error', 'Please select at least one product', 'error');
            return;
        }

        const prodLabel = this.productOptions.find(o => o.value === this.currentProduct.product)?.label;
        const whLabel = this.warehouseOptions.find(o => o.value === this.currentProduct.warehouse)?.label;

        const entry = {
            key: this.rowKey++,
            product: prodLabel,
            productId: this.currentProduct.product,
            warehouse: this.currentProduct.warehouse,
            warehouseName: whLabel,
            quantity: qty,

            lineItems: this.selectedRowsData.map(item => ({
                Id: item.Id
            }))

        };

        if (this.editKey === null) {
            this.products = [...this.products, entry];
        } else {
            this.products = this.products.map(p => p.key === this.editKey ? entry : p);

        }

        this.closeModal();
        this.selectedRowKeys = [];
        this.selectedRows = [];
    }

    handleRowSelection(event) {
        this.selectedRowsData = event.detail.selectedRows;
        this.selectedRowKeys = this.selectedRowsData.map(r => r.id);
        console.log('selectedRowsData: ', this.selectedRowsData);
    }

    closeModal() {
        this.isModalOpen = false;
    }

    generateNextDCNumber() {
        getLatestDCNumber({ name: this.consigneeHospitalName })
            .then(name => {
                this.deliveryChallanNumber = name;
            })
            .catch(() => {
                this.deliveryChallanNumber = 'DC-HOSP-0001';
            });
    }

    get hasLineItems() {
        return this.warehouseLineItems && this.warehouseLineItems.length > 0;
    }


    saveChallan() {
        if (!this.consigneeHospital) {
            return this.showToast('Error', 'Select consignee hospital', 'error');
        }
        if (!this.products.length) {
            return this.showToast('Error', 'Add at least one product', 'error');
        }
        const payload = {
            deliveryChallanNumber: this.deliveryChallanNumber,
            consigneeHospital: this.consigneeHospital,
            consignorDistributorId: this.consignorDistributorId,
            products: this.products
        };

        createDCForHospital({ payload: JSON.stringify(payload) })
            .then(recordId => {
                this.showToast('Success', 'Delivery Challan created successfully', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());

                this.showHospDCPage = false;
                this.message = `Delivery challan for ${this.consigneeHospitalName} has been created successfully. `;

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        objectApiName: 'Delivery_Challan__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                console.error('Error creating Delivery Challan:', error);
                this.showToast('Error', error?.body?.message || error?.message || 'Failed to create Delivery Challan', 'error');
            });


    }

    handleCreateDCClick() {
        this.products = [];
        this.consigneeHospital = '';
        this.warehouseLineItems = [];
        this.loadHospitals();
        this.loadWarehouses();
        this.generateNextDCNumber();
        this.getConsignor();
        this.showHospDCPage = true;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}