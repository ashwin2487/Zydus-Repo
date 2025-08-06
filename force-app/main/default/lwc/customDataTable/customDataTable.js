// customDataTable.js
import LightningDatatable from 'lightning/datatable';
import consumedAmountColumn from './consumedAmountColumn.html';

export default class CustomDataTable extends LightningDatatable {
    static customTypes = {
        editableConsumedAmount: {
            template: consumedAmountColumn,
            typeAttributes: ['value', 'editable', 'rowId']
        }
    };
}