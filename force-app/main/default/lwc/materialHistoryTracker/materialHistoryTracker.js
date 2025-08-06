import { LightningElement, track } from 'lwc';
import getSerialOrProductNumber from '@salesforce/apex/WarehouseInventoryController.getSerialOrProductNumber';
import getMaterialHistoryByCode from '@salesforce/apex/WarehouseInventoryController.getMaterialHistoryByCode';

// Definition of colors for each status
const STATUS_COLORS = {
    'Free': ' rgb(39, 174, 96)',
    'Committed': 'rgb(243, 156, 18)',
    'In Transit': 'rgb(52, 152, 219)',
    'Delivered': 'rgb(108, 122, 137)',
    'Consumed': 'rgb(22, 160, 133)',
    'Material Returned': 'rgb(192, 57, 43)'
};

export default class ProductHistoryTracker extends LightningElement {
    @track searchQuery = '';
    @track suggestions = [];
    @track showSuggestions = false;
    @track isLoading = false;
    @track noResults = false;
    @track historyRecords = [];

    // --- INPUT AND SEARCH SUGGESTION LOGIC ---

    handleInputChange(evt) {
        this.searchQuery = evt.target.value.trim();
        this.historyRecords = [];
        this.noResults = false;

        // Fetch suggestions if query is long enough
        if (this.searchQuery.length > 2) {
            getSerialOrProductNumber({ keyword: this.searchQuery })
                .then(res => {
                    this.suggestions = res;
                    this.showSuggestions = res.length > 0;
                })
                .catch(() => {
                    this.suggestions = [];
                    this.showSuggestions = false;
                });
        } else {
            this.suggestions = [];
            this.showSuggestions = false;
        }
    }

    handleKeyUp(evt) {
        if (evt.key === 'Enter') {
            this.showSuggestions = false;
            this.performSearch();
        }
    }

    handleSuggestionClick(evt) {
        this.searchQuery = evt.currentTarget.dataset.code;
        this.showSuggestions = false;
        this.performSearch();
    }

    // --- DATA FETCHING AND PROCESSING ---

    performSearch() {
        if (!this.searchQuery) {
            this.historyRecords = [];
            this.noResults = false;
            return;
        }

        this.isLoading = true;
        this.noResults = false;
        this.historyRecords = [];
        this.showSuggestions = false;

        getMaterialHistoryByCode({ code: this.searchQuery })
            .then(res => {
                console.log('res:', res);
                if (res && res.length > 0) {
                    this.historyRecords = this.processAndGroupHistoryData(res);
                } else {
                    this.noResults = true;
                }
            })
            .catch(error => {
                console.error('Error fetching product history:', error);
                this.noResults = true;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    processAndGroupHistoryData(data) {
        const STATUS_ORDER = {
            'Free': 1,
            'Committed': 2,
            'In Transit': 3,
            'Delivered': 4,
            'Consumed': 5,
            'Material Returned': 6
        };
    
        const WAREHOUSE_ORDER = {
            'Zydus': 1,
            'Super Distributor': 2,
            'Distributor': 3,
            'Sub Distributor': 4
        };
        const warehouseGroups = new Map();
        data.forEach(item => {
            const wId = item.warehouseId;
            if (!warehouseGroups.has(wId)) {
                warehouseGroups.set(wId, {
                    id: wId,
                    name: item.warehouseName,
                    poName: item.poName,
                    dcName: item.dcName,
                    soName: item.soName,
                    recordType: item.warehouseAccoutRecordType,
                    shouldShow: item.warehouseAccoutRecordType === 'Zydus',
                    events: []
                });
            }
            warehouseGroups.get(wId).events.push(item);
        });

        warehouseGroups.forEach(warehouse => {
            warehouse.events.sort((a, b) => {
                const dateA = new Date(a.historyRecord.CreatedDate);
                const dateB = new Date(b.historyRecord.CreatedDate);
                const dateDifference = dateA - dateB;

                if (dateDifference !== 0) {
                    return dateDifference;
                }

                const statusA = a.historyRecord.Field === 'created' ? 'Free' : a.historyRecord.NewValue;
                const statusB = b.historyRecord.Field === 'created' ? 'Free' : b.historyRecord.NewValue;
                const rankA = STATUS_ORDER[statusA] || 99;
                const rankB = STATUS_ORDER[statusB] || 99;

                return rankA - rankB;
            });

            warehouse.events = warehouse.events.map(item => {
                const record = item.historyRecord;
                let oldValue, newValue, status, isCreationEvent;

                if (record.Field === 'created') {
                    isCreationEvent = true;
                    oldValue = '—';
                    newValue = 'Free';
                    status = 'Free';
                } else {
                    isCreationEvent = false;
                    oldValue = record.OldValue;
                    newValue = record.NewValue;
                    status = record.NewValue;
                }

                const color = STATUS_COLORS[status] || 'rgb(128, 128, 128)';

                return {
                    id: record.Id,
                    oldValue: oldValue,
                    newValue: newValue,
                    userName: record.CreatedBy.Name,
                    timestamp: record.CreatedDate,
                    badgeStyle: `background-color: ${color}; color: white;`,
                    isCreationEvent: isCreationEvent
                };
            });
        });

        // 3. Convert Map to an Array and sort warehouses by the custom record type order
        const finalTimeline = Array.from(warehouseGroups.values()).sort((whA, whB) => {
            const rankA = WAREHOUSE_ORDER[whA.recordType] || 99;
            const rankB = WAREHOUSE_ORDER[whB.recordType] || 99;
            return rankA - rankB;
        });

        // 4. Mark the current location
        if (finalTimeline.length > 0) {
            const lastWarehouse = finalTimeline[finalTimeline.length - 1];
            lastWarehouse.isCurrentWarehouse = true;

            if (lastWarehouse.events.length > 0) {
                const lastEvent = lastWarehouse.events[lastWarehouse.events.length - 1];
                const lastEventColor = STATUS_COLORS[lastEvent.newValue] || 'rgb(128, 128, 128)';
                lastWarehouse.borderStyle = `border-left-color: ${lastEventColor};`;
            }
        }

        return finalTimeline;
    }
}