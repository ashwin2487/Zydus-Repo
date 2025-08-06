trigger InvoiceCreationTrigger on Invoice__c (before insert, after insert) {
    if(Trigger.isBefore && Trigger.isInsert){
        InvoiceCreationTriggerHandler.checkOutstandingCreditLimit(Trigger.new);
    }
    if(trigger.isAfter && trigger.isInsert){
        InvoiceCreationTriggerHandler.shareInvoices(trigger.new);
    }
}