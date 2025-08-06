import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import SHEET_JS from '@salesforce/resourceUrl/SheetJS';
import getPriceBook from '@salesforce/apex/PriceBookImportExportController.getPriceBook';
import getAllDataToBeExport from '@salesforce/apex/PriceBookImportExportController.getAllDataToBeExport';
import updatePricebookEntries from '@salesforce/apex/PriceBookImportExportController.updatePricebookEntries';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
const CHUNK_SIZE = 500;

export default class ImportExportPriceBook extends LightningElement {
    @track progress = 0;
    @track isLoading = false;
    @track loadingMessage = '';
    @track activeSection = 'export';
    @track selectedPriceBooks = [];
    @track priceBookOptions = [];
    isExporting = false;
    @track isExportBtnDisabled;
    @track exportLable = 'Export CSV File';
    @track disableImportProcessBtn;
    @track importLable = 'Import CSV File';
  
    radioOptions = [
        { label: 'Export', value: 'export' },
        { label: 'Import', value: 'import' },
    ]

    handleRadioChange(event) {
        this.activeSection = event.detail.value;
    }

    @wire(getPriceBook)
    wiredPriceBooks(result) {
        this.isLoading = true;
        const { data, error } = result;
        if (data) {
            this.priceBookOptions = data.map(pb => {
                return {
                    label: pb.Name,
                    value: pb.Id
                };
            });
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.priceBookOptions = [];
            console.error('Error loading price books:', JSON.stringify(this.error));
        }
        this.isLoading = false;
    }


    get isExportView() {
        return this.activeSection === 'export';
    }

    get isImportView() {
        return this.activeSection === 'import';
    }

    get priceBookOptions() {
        return this.priceBookOptions;
    }

    get hasSelectedPriceBooks() {
        return this.selectedPriceBooks && this.selectedPriceBooks.length > 0;
    }

    get isExportDisabled() {
        return this.isExportBtnDisabled || !this.hasSelectedPriceBooks;
    }

    get selectedPills() {
        return this.selectedPriceBooks.map(value => {
            const option = this.priceBookOptions.find(opt => opt.value === value);
            return {
                label: option ? option.label : value,
                name: value,
                type: 'avatar',
                fallbackIconName: 'standard:pricebook'
            };
        });
    }

    handlePriceBookSelectionChange(event) {
        this.selectedPriceBooks = event.detail.value;
    }

    handlePillRemove(event) {
        const removedValue = event.detail.item.name;
        this.selectedPriceBooks = this.selectedPriceBooks.filter(value => value !== removedValue);
    }


    handleExport() {
        if (!this.hasSelectedPriceBooks) {
            this.showToast('No Selection', 'Please select at least one Price Book to export.', 'warning');
            return;
        }

        this.isExportBtnDisabled = true;
        this.isExporting = true;
        this.exportLable = 'Processing Export...';
        getAllDataToBeExport({ PBIds: this.selectedPriceBooks })
            .then(data => {
                console.log("DATA: ", data);
                if (data && data.length > 0) {
                    this.downloadCSV(data);
                    this.showToast('Success', 'Price Book data exported successfully.', 'success');
                } else {
                    this.showToast('No Data', 'No price book entries found for the selected price books.', 'info');
                }

            })
            .catch(error => {
                console.error('Export Error:', error);
                this.showToast('Export Failed', 'An error occurred during export.', 'error');
            })
            .finally(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
                this.isExportBtnDisabled = false;
                this.exportLable = 'Export CSV File';
                this.isExporting = false;
            });
    }

    downloadCSV(data) {
        const headers = [
            'Price Book Entry ID', 'Price Book ID', 'Price Book Name', 'Product Name',
            'Base Price[Before Tax]', 'Is Active', 'Minimum Order Quantity', 'Credit Note Amount',
            'Bill Discount Amount', 'ARS Minimum Stock Threshold'
        ];

        const csvRows = data.map(row => {
            const get = (p, o) => p.reduce((xs, x) => (xs && xs[x]) ? xs[x] : null, o);

            const rowData = [
                row.Id,
                row.Zydus_Price_Book__c,
                get(['Zydus_Price_Book__r', 'Name'], row),
                get(['Zydus_Product__r', 'Name'], row),
                row.Unit_Price__c,
                row.Is_Active__c,
                row.Minimum_Order_Quantity_MOQ__c,
                row.Credit_Note_Amount__c,
                row.Bill_Discount_Amount__c,
                row.ARS_Minimum_Stock_Threshold__c
            ];
            return rowData.map(val => (val === null || val === undefined) ? '' : `"${String(val).replace(/"/g, '""')}"`).join(',');
        });

        const csvString = [headers.join(','), ...csvRows].join('\n');

        const hiddenElement = document.createElement('a');
        hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvString);
        hiddenElement.target = '_blank';
        hiddenElement.download = `PriceBookExport_${new Date().toISOString().slice(0, 10)}.csv`;
        hiddenElement.click();
    }

    /*.......IMPORT PROCESS......*/
    acceptedFormats = ['.xls', '.xlsx'];
    @track fileName;
    @track fileUploaded = false;
    _sheetJsLoaded = false;

    renderedCallback() {
        if (!this._sheetJsLoaded) {
            loadScript(this, SHEET_JS)
                .then(() => {
                    this._sheetJsLoaded = true;
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to load the Excel parsing library.', 'error');
                    console.error('Error loading SheetJS:', error);
                });
        }
    }

    handleFileChange(event) {
        if (event.target.files.length > 0) {
            this.file = event.target.files[0];
            this.fileName = this.file.name;
            this.fileUploaded = true;
        }
    }

   async handleStartProcess() {
        if (!this.file) {
            this.showToast('Error', 'Please select a file first.', 'error');
            return;
        }
        if (!this._sheetJsLoaded) {
            this.showToast('Error', 'File parsing library is not loaded yet.', 'error');
            return;
        }

        this.isLoading = true;
        this.importLable = 'Importing...';
        this.disableImportProcessBtn = true;
        try {
            const parsedData = await this.parseFile(this.file);

            if (!parsedData || parsedData.length === 0) {
                this.showToast('Warning', 'The file is empty or could not be parsed.', 'warning');
                this.isLoading = false;
                return;
            }
            const mappedData = parsedData.map(row => {
                return {
                    Id: row['Price Book Entry ID'],
                    Unit_Price__c: row['Base Price[Before Tax]'],
                    Is_Active__c: row['Is Active'],
                    Minimum_Order_Quantity_MOQ__c: row['Minimum Order Quantity'],
                    Credit_Note_Amount__c: row['Credit Note Amount'],
                    Bill_Discount_Amount__c: row['Bill Discount Amount'],
                    ARS_Minimum_Stock_Threshold__c: row['ARS Minimum Stock Threshold']
                };
            });

            const chunks = this.splitIntoChunks(mappedData, CHUNK_SIZE);
            let totalSuccess = 0;
            let totalErrors = 0;

            const updatePromises = chunks.map(chunk => {
                const jsonString = JSON.stringify(chunk);
                return updatePricebookEntries({ jsonString: jsonString });
            });

            const results = await Promise.allSettled(updatePromises);
            
            results.forEach(result => {
                if (result.status === 'fulfilled') {
                    const matchResult = result.value.match(/\d+/);
                    if (matchResult) {
                        const count = parseInt(matchResult[0], 10);
                        totalSuccess += count;
                    }
                } else {
                    totalErrors++;
                    console.error('Error updating chunk:', result.reason);
                }
            });

            if (totalErrors > 0) {
                 this.showToast('Partial Success', `Successfully updated ${totalSuccess} records. Failed to process ${totalErrors} chunk(s).`, 'warning');
            } else {
                 this.showToast('Success', `Successfully updated all ${totalSuccess} records.`, 'success');
            }
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', `An error occurred: ${error.message}`, 'error');
            console.error('Processing failed:', error);
        } finally {
            this.importLable = 'Import CSV File';
            this.disableImportProcessBtn = false;
            this.isLoading = false;
        }
    }

    parseFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = (event) => {
                try {
                    const data = new Uint8Array(event.target.result);
                    const workbook = XLSX.read(data, { type: 'array' });

                    const firstSheetName = workbook.SheetNames[0];
                    const worksheet = workbook.Sheets[firstSheetName];

                    const jsonData = XLSX.utils.sheet_to_json(worksheet);

                    resolve(jsonData);
                } catch (e) {
                    reject(e);
                }
            };
            
            reader.onerror = (event) => {
                reject(new Error("Error reading file: " + reader.error));
            };
            reader.readAsArrayBuffer(file);
        });
    }

    splitIntoChunks(array, size) {
        const chunks = [];
        for (let i = 0; i < array.length; i += size) {
            chunks.push(array.slice(i, i + size));
        }
        return chunks;
    }

    get dropZoneClass() {
        let baseClass = 'drop-zone';
        if (this.fileName) {
            return `${baseClass} uploaded`;
        }
        return baseClass;
    }

    handleRemoveFile() {
        this.file = null;
        this.fileUploaded = false;
        this.fileName = null;
    }
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            }),
        );
    }
}