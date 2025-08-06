// consumedAmountColumn.js
import { LightningElement, api } from 'lwc';

export default class ConsumedAmountColumn extends LightningElement {
    @api typeAttributes;

    get disabled() {
        return !this.typeAttributes?.editable;
    }

    handleChange(event) {
        const newValue = event.target.value;

        this.dispatchEvent(
            new CustomEvent('cellchange', {
                detail: {
                    value: newValue,
                    rowId: this.typeAttributes?.rowId
                },
                bubbles: true,
                composed: true
            })
        );
    }
}