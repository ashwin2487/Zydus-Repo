import { LightningElement, track, wire } from 'lwc';
import getAllApprovalHistory from '@salesforce/apex/ZydusReportsController.getAllApprovalHistory';
import SHEET_JS from '@salesforce/resourceUrl/SheetJS';
import getReportLinks from '@salesforce/apex/ZydusReportsController.getReportLinks';
import getNonMovingInventory from '@salesforce/apex/ZydusReportsController.getNonMovingInventory';
import getSerialMovementReport from '@salesforce/apex/ZydusReportsController.getSerialMovementReport';
import getMaterialHistory from '@salesforce/apex/ZydusReportsController.getMaterialHistory';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInvoiceWiseOutstanding from '@salesforce/apex/ZydusReportsController.getInvoiceWiseOutstanding';

export default class ApprovalHistoryTab extends LightningElement {
    @track category = '';
    @track activeSections = [];
    @track pageSize = 10;
    @track pageNumber = 1;
    @track data = [];
    @track error;
    @track reportLinks = [];
    @track zydusDateRange = '';
    @track nonMovingData = [];
    @track groupedNonMovingData = [];
    @track nonMovingError;
    expandedGroups = new Set();
    @track zydusSerialData = [];
    @track zydusSerialError;
    @track totalRecords = 0;
    @track totalPages = 1;
    @track outstandingReportData = [];

    get isFirstPage() {
        return this.pageNumber === 1;
    }

    get isLastPage() {
        return this.pageNumber === this.totalPages;
    }

    categoryOptions = [
        { label: '-- Select Category --', value: '' },
        { label: 'Hospital', value: 'Hospital' },
        { label: 'Distributor', value: 'Account' }
    ];
    dateRangeOptions = [
        { label: 'Last 30 Days', value: '30' },
        { label: 'Last 60 Days', value: '60' },
        { label: 'Last 90 Days', value: '90' },
        { label: 'Till Date', value: 'ALL' }
    ];

    selectedSalesCategory = '';

    salesInvoiceCategoryOptions = [
        { label: 'Super Distributor Invoice', value: 'Super Distributor Invoice' },
        { label: 'Distributor Invoice', value: 'Distributor Invoice' },
        { label: 'Sub Distributor Invoice', value: 'Sub Distributor Invoice' },
        { label: 'Hospital Invoice', value: 'Hospital Invoice' }
    ];


    outstandingReportColumns = [
        { label: 'Regions', fieldName: 'regions' },
        { label: 'Sales Person Name', fieldName: 'salesPerson' },
        { label: 'Distributor', fieldName: 'distributor' },
        { label: 'Hospital', fieldName: 'hospital' },
        { label: 'Invoice No', fieldName: 'invoiceNumber' },
        { label: 'Invoice Date', fieldName: 'invoiceDate', type: 'date' },
        { label: 'Total Outstanding', fieldName: 'totalOutstanding', type: 'currency' },
        { label: 'Not Due', fieldName: 'notDue', type: 'currency' },
        { label: 'Payment Term', fieldName: 'paymentTerm' },
        { label: '0-30 Days', fieldName: 'days0to30', type: 'currency' },
        { label: '31-60 Days', fieldName: 'days31to60', type: 'currency' },
        { label: '61-90 Days', fieldName: 'days61to90', type: 'currency' },
        { label: '91-120 Days', fieldName: 'days91to120', type: 'currency' },
        { label: '120-180 Days', fieldName: 'days120to180', type: 'currency' },
        { label: '>180 Days', fieldName: 'daysOver180', type: 'currency' },
        { label: 'Last Payment Date', fieldName: 'lastPaymentDate', type: 'date' }
    ];

    columns = [
        { label: 'Record Name', fieldName: 'recordName' },
        { label: 'L1 Approved', fieldName: 'l1Approved', type: 'boolean' },
        { label: 'L2 Approved', fieldName: 'l2Approved', type: 'boolean' },
        { label: 'Active', fieldName: 'isActive', type: 'boolean' },
        { label: 'Submission Date', fieldName: 'submissionDate', type: 'date' },
        { label: 'Overall Status', fieldName: 'approvalStatus' },
        { label: 'Approver', fieldName: 'approverName' },
        { label: 'Step Status', fieldName: 'stepStatus' },
        { label: 'Comments', fieldName: 'comments' },
        { label: 'Action Date', fieldName: 'actionDate', type: 'date' }
    ];

    nonMovingColumns = [
        { label: 'Brand', fieldName: 'brand' },
        { label: 'Material Name', fieldName: 'materialName' },
        { label: 'Size', fieldName: 'size' },
        { label: 'Current WH', fieldName: 'currentWH' },
        { label: 'Stock Qty', fieldName: 'stockQty', type: 'number' },
        { label: 'Last Used Date', fieldName: 'lastUsedDate', type: 'date' },
        { label: 'Days Idle', fieldName: 'daysIdle', type: 'number' },
        { label: 'Recommended WH', fieldName: 'recommendedWH' },
        { label: 'Recommended Action', fieldName: 'recommendedAction' }
    ];

    connectedCallback() {
        //this.fetchReportLinks();
        //this.fetchNonMovingInventory();
        this.fetchMaterialHistoryData();
    }

    handleCategoryChange(event) {
        this.category = event.detail.value;
        this.activeSections = ['approvalHistory'];
        this.fetchApprovalHistory();
    }

    handleSalesCategoryChange(event) {
        this.selectedSalesCategory = event.detail.value;
        this.fetchOutstandingReport();
    }

    fetchApprovalHistory() {
        getAllApprovalHistory({ category: this.category })
            .then(result => {
                this.data = result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = this.extractErrorMessage(error);
                this.data = [];
            });
    }

    // fetchReportLinks() {
    //     getReportLinks()
    //         .then(result => {
    //             this.reportLinks = result;
    //         })
    //         .catch(error => {
    //             console.error('Error fetching report links:', error);
    //         });
    // }
    @wire(getReportLinks)
    wiredReportLinks({ error, data }) {
        if (data) {
            this.reportLinks = data;
        } else if (error) {
            console.error('Error fetching report links:', error);
        }
    }
    // fetchNonMovingInventory() {
    //     getNonMovingInventory()
    //         .then(result => {
    //             if (!result || typeof result !== 'object') {
    //                 this.nonMovingError = 'Unexpected data format from server.';
    //                 this.nonMovingData = [];
    //                 this.groupedNonMovingData = [];
    //                 return;
    //             }

    //             this.nonMovingData = result;
    //             this.groupedNonMovingData = this.groupByRecommendedAction(result);
    //             this.nonMovingError = undefined;
    //         })
    //         .catch(error => {
    //             this.nonMovingError = this.extractErrorMessage(error);
    //             this.nonMovingData = [];
    //             this.groupedNonMovingData = [];
    //         });
    // }
    @wire(getNonMovingInventory)
    wiredNonMovingInventory({ error, data }) {
        if (data && typeof data === 'object') {
            this.nonMovingData = data;
            this.groupedNonMovingData = this.groupByRecommendedAction(data);
            this.nonMovingError = undefined;
        } else if (error) {
            this.nonMovingError = this.extractErrorMessage(error);
            this.nonMovingData = [];
            this.groupedNonMovingData = [];
        }
    }
    fetchZydusSerialReport() {
        getSerialMovementReport({
            pageSize: this.pageSize,
            pageNumber: this.pageNumber,
            dateRangeOption: this.zydusDateRange
        })
            .then(result => {
                if (!result || !Array.isArray(result.records)) {
                    console.error('Invalid response from Apex getSerialMovementReport:', result);
                    this.zydusSerialData = [];
                    this.totalRecords = 0;
                    this.totalPages = 1;
                    this.zydusSerialError = 'Unexpected data format from server.';
                    return;
                }

                const records = result.records || [];
                const totalRecords = result.totalRecords || 0;

                this.totalRecords = totalRecords;
                this.totalPages = Math.ceil(totalRecords / this.pageSize);

                this.zydusSerialData = records.map(row => ({
                    ...row,
                    brand: row.brand || '----',
                    materialCode: row.materialCode || '----',
                    materialName: row.materialName || '----',
                    zydusAmountFormatted: this.formatCurrency(row.zydusAmount),
                    zydusToSuperMarginFormatted: this.formatCurrency(row.zydusToSuperMargin),
                    zydusToSuperMarginPercentFormatted: this.formatPercent(row.zydusToSuperMarginPercent),
                    superDistributorAmountFormatted: this.formatCurrency(row.superDistributorAmount),
                    superToNextMarginFormatted: this.formatCurrency(row.superToNextMargin),
                    superToNextMarginPercentFormatted: this.formatPercent(row.superToNextMarginPercent),
                    distributorAmountFormatted: this.formatCurrency(row.distributorAmount),
                    distributorToNextMarginFormatted: this.formatCurrency(row.distributorToNextMargin),
                    distributorToNextMarginPercentFormatted: this.formatPercent(row.distributorToNextMarginPercent),
                    subDistributorAmountFormatted: this.formatCurrency(row.subDistributorAmount),
                    subToHospitalMarginFormatted: this.formatCurrency(row.subToHospitalMargin),
                    subToHospitalMarginPercentFormatted: this.formatPercent(row.subToHospitalMarginPercent),
                    subDistributorPurchasePriceFormatted: this.formatCurrency(row.subDistributorPurchasePrice),
                    distributorPurchasePriceFormatted: this.formatCurrency(row.distributorPurchasePrice),
                    superDistributorPurchasePriceFormatted: this.formatCurrency(row.superDistributorPurchasePrice),
                    hospitalName: row.hospitalName || '----'
                }));

                this.zydusSerialError = undefined;
            })
            .catch(error => {
                this.zydusSerialError = this.extractErrorMessage(error);
                this.zydusSerialData = [];
                this.totalRecords = 0;
                this.totalPages = 1;
            });
    }

    handlePreviousPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.fetchZydusSerialReport();
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.fetchZydusSerialReport();
        }
    }

    handleZydusDateRangeChange(event) {
        this.zydusDateRange = event.detail.value;
        this.fetchZydusSerialReport();
    }


    formatCurrency(value) {
        return value != null ? `₹${parseFloat(value).toFixed(2)}` : '----';
    }

    formatPercent(value) {
        return value != null ? `${parseFloat(value).toFixed(2)}%` : '----';
    }

    extractErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (typeof error?.body?.message === 'string') {
            return error.body.message;
        } else if (typeof error?.message === 'string') {
            return error.message;
        }
        return 'Unknown error';
    }

    groupByRecommendedAction(dataMap) {
        return Object.entries(dataMap).map(([key, items]) => ({
            id: `group-${key}`,
            label: key,
            items,
            isExpanded: this.expandedGroups.has(key),
            toggleLabel: this.expandedGroups.has(key) ? 'utility:hide' : 'utility:preview',
            sortByStockQtyValue: `${key}__stockQty`,
            sortByDaysIdleValue: `${key}__daysIdle`
        }));
    }

    toggleGroup(event) {
        const groupLabel = event.target.dataset.label;
        this.expandedGroups.has(groupLabel)
            ? this.expandedGroups.delete(groupLabel)
            : this.expandedGroups.add(groupLabel);

        this.groupedNonMovingData = this.groupByRecommendedAction(this.nonMovingData);
    }

    handleSortClick(event) {
        const [groupLabel, field] = event.target.value.split('__');
        const group = this.groupedNonMovingData.find(g => g.label === groupLabel);
        if (!group) return;

        const sortedItems = [...group.items].sort((a, b) => (b[field] || 0) - (a[field] || 0));
        this.groupedNonMovingData = this.groupedNonMovingData.map(g =>
            g.label === groupLabel ? { ...g, items: sortedItems } : g
        );
    }


    fetchOutstandingReport() {
        getInvoiceWiseOutstanding({ category: this.selectedSalesCategory })
            .then(result => {
                this.outstandingReportData = result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.data = [];
                console.error('Error loading data: ', error);
            });
    }
    /* FOR MATERIAL HISTORY */
    @track processedData = [];
    allData = [];
    @track materialPageNumber = 1;
    @track materialPageSize = 10;
    @track materialHistoryPageSize;
    @track materialTotalRecords = 0;
    @track materialTotalPages = 0;
    @track materialHistoryBtnDisable = false;
    @track materialHistoryLabel = 'Export';
    @track isMaterialLoading = false;
    _sheetJsLoaded = false;

    materialOptions = [
        { label: '100', value: '100' },
        { label: '500', value: '500' },
        { label: '1000', value: '1000' },
        { label: 'All', value: 'All' }
    ];

    connectedCallback() {
        this.fetchMaterialHistoryData();
    }

    fetchMaterialHistoryData() {
        this.isMaterialLoading = true;
        getMaterialHistory()
            .then(result => {
                if (result) {
                    this.transformData(result);
                }
            })
            .catch(error => {
                console.error('Error fetching material history:', error);
                this.processedData = [];
            }).finally(() => {
                this.isMaterialLoading = false;
            });
    }

    getStageKey(warehouseName) {
        if (!warehouseName) return null;
        const name = warehouseName.toLowerCase();
        if (name.includes('super distributor')) return 'superDistributor';
        if (name.includes('sub distributor')) return 'subDistributor';
        if (name.includes('distributor')) return 'distributor';
        if (name.includes('hospital')) return 'hospital';
        if (name.includes('zydus')) return 'zydus';
        return null;
    }

    transformData(data) {
        const STAGES = [
            'zydus', 'superDistributor', 'distributor', 'subDistributor', 'hospital'
        ];
        const STATUS_ORDER = {
            'Added': 0,
            'Free': 1,
            'Committed': 2,
            'In Transit': 3,
            'Delivered': 4,
            'Consumed': 5,
            'Material Returned': 6
        };

        const defaultStageData = {
            warehouseName: '', by: '', statusFrom: '',
            statusTo: '', date: '', po: '', so: '', dc: ''
        };

        // Step 1: Group data by serial number
        const serialMap = {};
        for (let rec of data) {
            let sn = rec.serialNumber;
            if (!serialMap[sn]) {
                serialMap[sn] = {
                    brand: rec.brand,
                    materialCode: rec.materialCode,
                    batchName: rec.batchName,
                    serialNumber: rec.serialNumber,
                    stages: {
                        zydus: [], superDistributor: [], distributor: [],
                        subDistributor: [], hospital: []
                    }
                };
            }

            let stageKey = this.getStageKey(rec.warehouseName);
            if (stageKey) {
                // Handle creation events and regular status changes
                let isCreationEvent = false;
                let oldValue = rec.historyRecord?.OldValue || '';
                let newValue = rec.historyRecord?.NewValue || '';

                // Special handling for creation events
                if (rec.historyRecord?.Field === 'created') {
                    isCreationEvent = true;
                    oldValue = '---';  // Show dash for "from" status
                    newValue = 'Added';  // Show "Added" instead of "Free"
                }
                // Handle cases where Field is 'created' but OldValue/NewValue might be present
                else if (rec.historyRecord?.Field === 'created' && !oldValue && !newValue) {
                    isCreationEvent = true;
                    oldValue = '---';
                    newValue = 'Added';
                }

                serialMap[sn].stages[stageKey].push({
                    warehouseName: rec.warehouseName || '',
                    by: rec.historyRecord?.CreatedBy?.Name || '',
                    statusFrom: oldValue,
                    statusTo: newValue,
                    date: rec.historyRecord?.CreatedDate || '',
                    po: rec.poName || '',
                    so: rec.soName || '',
                    dc: rec.dcName || '',
                    isCreationEvent: isCreationEvent
                });
            }
        }

        // Step 2: Sort each stage's array by date, then by status order
        for (let sn in serialMap) {
            let stages = serialMap[sn].stages;
            for (let stage of STAGES) {
                stages[stage].sort((a, b) => {
                    // First sort by date (oldest to newest)
                    if (a.date < b.date) return -1;
                    if (a.date > b.date) return 1;

                    // If same date, sort by status order (Added comes first)
                    const aStatusIdx = STATUS_ORDER[a.statusFrom] !== undefined ? STATUS_ORDER[a.statusFrom] : 99;
                    const bStatusIdx = STATUS_ORDER[b.statusFrom] !== undefined ? STATUS_ORDER[b.statusFrom] : 99;
                    return aStatusIdx - bStatusIdx;
                });
            }
        }

        // Step 3: Build table rows (existing logic)
        let allRows = [];
        for (let sn in serialMap) {
            const serialObj = serialMap[sn];
            const counts = Object.values(serialObj.stages).map(arr => arr.length);
            const maxRows = Math.max(...counts, 1);
            for (let i = 0; i < maxRows; i++) {
                let row = {
                    isFirstRow: i === 0, rowspan: maxRows,
                    brand: serialObj.brand, materialCode: serialObj.materialCode,
                    batchName: serialObj.batchName, serialNumber: serialObj.serialNumber
                };
                for (const stage of STAGES) {
                    row[stage] = serialObj.stages[stage][i] || { ...defaultStageData };
                }
                allRows.push(row);
            }
        }

        this.allData = allRows;
        this._uniqueSerials = Object.keys(serialMap);
        this.materialTotalRecords = this._uniqueSerials.length;
        this.materialTotalPages = Math.ceil(this.materialTotalRecords / this.materialPageSize) || 1;
        this.setPageData();
    }

    setPageData() {
        const startIdx = (this.materialPageNumber - 1) * this.materialPageSize;
        const endIdx = startIdx + this.materialPageSize;
        const serialsOnPage = new Set(this._uniqueSerials.slice(startIdx, endIdx));
        this.processedData = this.allData.filter(r => serialsOnPage.has(r.serialNumber));
    }

    handleMaterialPreviousPage() {
        if (this.materialPageNumber > 1) {
            this.materialPageNumber--;
            this.setPageData();
        }
    }

    handleMaterialNextPage() {
        if (this.materialPageNumber < this.materialTotalPages) {
            this.materialPageNumber++;
            this.setPageData();
        }
    }

    get isMaterialFirstPage() {
        return this.materialPageNumber === 1;
    }

    get isMaterialLastPage() {
        return this.materialPageNumber >= this.materialTotalPages;
    }

    handleMaterialPageSizeChange(event) {
        this.isMaterialLoading = true;
        this.materialHistoryPageSize = event.target.value;
        if (this.materialHistoryPageSize === 'All') {
            this.materialPageSize = this.materialTotalRecords;
        } else {
            this.materialPageSize = parseInt(this.materialHistoryPageSize);
        }
        this.setPageData();
        this.materialTotalPages = Math.ceil(this.materialTotalRecords / this.materialPageSize) || 1;
        this.isMaterialLoading = false;
    }
    navigateToTab() {
        window.open('/lightning/n/Material_History_Tracker', '_blank');
    }

    renderedCallback() {
        if (!this._sheetJsLoaded) {
            loadScript(this, SHEET_JS)
                .then(() => {
                    this._sheetJsLoaded = true;
                    console.log('SheetJS loaded successfully');
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to load the Excel library.', 'error');
                    console.error('Error loading SheetJS:', error);
                });
        }
    }

    downloadExcelMaterialHistory() {
        if (!this._sheetJsLoaded) {
            this.showToast('Error', 'Library not loaded yet. Please wait.', 'error');
            return;
        }

        const table = this.template.querySelector('[data-id="materialHistoryData"]');
        if (!table) {
            this.showToast('Error', 'Table not found for export.', 'error');
            return;
        }

        this.materialHistoryLabel = 'Exporting...';
        this.materialHistoryBtnDisable = true;

        setTimeout(() => {
            try {
                const book = XLSX.utils.table_to_book(table, { sheet: 'Material History' });
                XLSX.writeFile(book, 'MaterialHistory.xlsx');
                this.showToast('Success', 'File exported successfully.', 'success');
            } catch (error) {
                console.error('Export failed:', error);
                this.showToast('Error', 'An error occurred during file export.', 'error');
            } finally {
                this.materialHistoryLabel = 'Export';
                this.materialHistoryBtnDisable = false;
            }
        }, 0);
    }

    exportZydusSerial() {
        if (!this.zydusSerialData || this.zydusSerialData.length === 0) {
            this.showToast('Error', 'No data to export.', 'error');
            return;
        }
        if (!this._sheetJsLoaded) {
            this.showToast('Error', 'Library not loaded yet. Please wait.', 'error');
            return;
        }
        const table = this.template.querySelector('[data-id="zydusSerialTableId"]');
        if (!table) {
            this.showToast('Error', 'Table not found for export.', 'error');
            return;
        }

        this.materialHistoryLabel = 'Exporting...';
        this.materialHistoryBtnDisable = true;

        setTimeout(() => {
            try {
                // This code runs AFTER the UI has been updated
                const workbook = XLSX.utils.table_to_book(table, { sheet: 'Zydus Serials' });
                XLSX.writeFile(workbook, 'ZydusSerials.xlsx');
                this.showToast('Success', 'File exported successfully.', 'success');
            } catch (error) {
                console.error('Export failed:', error);
                this.showToast('Error', 'An error occurred during export.', 'error');
            } finally {
                this.materialHistoryLabel = 'Export';
                this.materialHistoryBtnDisable = false;
            }
        }, 0);
    }

    exportNonMovingInventory(event) {
        const groupLabel = event.currentTarget.dataset.label;

        const groupToExport = this.groupedNonMovingData.find(group => group.label === groupLabel);

        if (!groupToExport || !groupToExport.items || groupToExport.items.length === 0) {
            this.showToast('Error', 'No data to export.', 'error');
            return;
        }
        const dataToExport = groupToExport.items;

        const fileName = `${groupLabel.replace(/ /g, '_')}.xlsx`;

        const cleanData = dataToExport.map(record => {
            return {
                'Brand': record.brand,
                'Current Warehouse': record.currentWH,
                'Days Idle': record.daysIdle,
                'Last Used Date': record.lastUsedDate,
                'Material Name': record.materialName,
                'Recommendation': record.recommendation,
                'Recommended Size': record.recommenSize,
                'Stock Qty': record.stockQty
            };
        });

        try {
            this.materialHistoryLabel = 'Exporting...';
            this.materialHistoryBtnDisable = true;
            const workbook = XLSX.utils.book_new();
            const worksheet = XLSX.utils.json_to_sheet(cleanData);

            XLSX.utils.book_append_sheet(workbook, worksheet, groupLabel + ' Non-Moving Inventory');
            XLSX.writeFile(workbook, fileName);

            this.showToast('Success', 'File exported successfully. ✅', 'success');

        } catch (error) {
            console.error('Export failed:', error);
            this.showToast('Error', 'An error occurred during export.', 'error');
        } finally {
            this.materialHistoryLabel = 'Export';
            this.materialHistoryBtnDisable = false;
        }
    }

    exportApprovalHistory() {

        if (!this.data || this.data.length === 0) {
            this.showToast('Error', 'No data to export.', 'error');
            return;
        }

        this.materialHistoryLabel = 'Exporting...';
        this.materialHistoryBtnDisable = true;
        const cleanData = this.data.map(record => {
            return {
                'Record Name': record.recordName,
                'L1 Approved': record.l1Approved,
                'L2 Approved': record.l2Approved,
                'Is Active': record.isActive,
                'Submission Date': this.formatDate(record.submissionDate),
                'Approval Status': record.approvalStatus,
                'Approver Name': record.approverName,
                'Step Status': record.stepStatus,
                'Comments': record.comments,
                'Action Date': this.formatDate(record.actionDate)
            };
        });

        console.log('Clean Data', cleanData);

        const XLSX = window.XLSX;
        const workbook = XLSX.utils.book_new();
        const worksheet = XLSX.utils.json_to_sheet(cleanData);
        XLSX.utils.book_append_sheet(workbook, worksheet, 'Distributor Approval History');
        XLSX.writeFile(workbook, `approvalHistory${this.category}.xlsx`);
        this.showToast('Success', 'File exported successfully. ✅', 'success');

        this.materialHistoryLabel = 'Export';
        this.materialHistoryBtnDisable = false;
    }
    exportOutstandingReport() {

        if (!this.outstandingReportData || this.outstandingReportData.length === 0) {
            this.showToast('Error', 'No data to export.', 'error');
            return;
        }

        this.materialHistoryLabel = 'Exporting...';
        this.materialHistoryBtnDisable = true;

        const cleanData = this.outstandingReportData.map(record => {
            return {
                'Regions': record.regions,
                'Sales Person Name': record.salesPerson,
                'Distributor': record.distributor,
                'Hospital': record.hospital,
                'Invoice No': record.invoiceNo,
                'Invoice Date': record.invoiceDate,
                'Total Outstanding': record.totalOS,
                'Not Due': record.notDue,
                'Payment Term': record.paymentTerm,
                '0-30 Days': record.daystillto30,
                '31-60 Days': record.days31to60,
                '61-90 Days': record.days61to90,
                '91-120 Days': record.days91to120,
                '120-180 Days': record.days120to180,
                '>180 Days': record.daysSlot1,
                'Last Pay': record.lastPaymentDate
            };
        });

        const XLSX = window.XLSX;
        const workbook = XLSX.utils.book_new();
        const worksheet = XLSX.utils.json_to_sheet(cleanData);

        XLSX.utils.book_append_sheet(workbook, worksheet, 'Outstanding Payment Report');
        XLSX.writeFile(workbook, `outstandingPaymentReport_${this.selectedSalesCategory}.xlsx`);
        this.showToast('Success', 'File exported successfully. ✅', 'success');

        this.materialHistoryLabel = 'Export';
        this.materialHistoryBtnDisable = false;
    }
    formatDate(datetime) {
        if (!datetime) return '';
        const options = {
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', hour12: true
        };
        return new Date(datetime).toLocaleString('en-IN', options);
    };

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
    }

}