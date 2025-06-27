import { LightningElement, track, wire, api } from 'lwc';
import getInventoryData from '@salesforce/apex/WarehouseInventoryController.getInventoryData';
import getUserWarehouses from '@salesforce/apex/WarehouseInventoryController.getUserWarehouses';

export default class WarehouseInventoryShow extends LightningElement {
  @api recordId;
  @track selectedStatus = 'Free';
  @track data = [];
  @track statusOptions = [
    { label: 'Free', value: 'Free' },
    { label: 'Committed', value: 'Committed' },
    { label: 'In Transit', value: 'In Transit' }
  ];
  @track warehouseIdsToFetch=[];
  @track warehouseOptions = [];
  @track selectedWarehouse = 'all';

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

  @wire(getUserWarehouses, { recordId: '$recordId' })
  wiredWarehouses({ error, data }) {
    if (data) {
      this.warehouseIds = data.map(w => w.Id);
      this.warehouseOptions = [
        { label: 'All', value: 'all' },
        ...data.map(w => ({ label: w.Name, value: w.Id }))
      ];
      this.warehouseIdsToFetch = this.warehouseIds;
      this.fetchInventory();
    }
  }

  handleWarehouseOptionsChange(e) {
    this.selectedWarehouse = e.detail.value;

    if(this.selectedWarehouse=='all'){
      this.warehouseIdsToFetch = this.warehouseIds;
    }else{
      this.warehouseIdsToFetch=[this.selectedWarehouse];
    }
    this.fetchInventory();
  }

  handleStatusOptionsChange(e) {
    this.selectedStatus = e.detail.value;
    this.fetchInventory();
  }

  fetchInventory() {
    if (!this.warehouseIdsToFetch?.length) return;
    getInventoryData({ warehouseIds: this.warehouseIdsToFetch, statusFilter: this.selectedStatus })
      .then(rows => {
        this.data = rows.map(row => {
          const cleanedRow = {};
          for (const key in row) {
            const value = row[key];
            cleanedRow[key] = (value === null || value === undefined || value === '') ? 'N/A' : value;
          }
          return cleanedRow;
        });
      })
      .catch(console.error);
  }
}