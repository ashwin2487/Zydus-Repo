trigger InvoiceProductLineItemTrigger on Invoice_Product_Line_Item__c (after insert, before insert) {
    
    if(Trigger.isAfter && Trigger.isInsert){
        InvoiceProductLineItemTriggerHandler.createCreditNote(Trigger.new);
    }
    
    if(Trigger.isBefore && Trigger.isInsert){
        InvoiceProductLineItemTriggerHandler.preventInvoiceCreationIfProductExpired(Trigger.new);
    }
}