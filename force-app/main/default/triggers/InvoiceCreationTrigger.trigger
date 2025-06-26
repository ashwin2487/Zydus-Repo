trigger InvoiceCreationTrigger on Invoice__c (before insert) {
    if(Trigger.isBefore && Trigger.isInsert){
        InvoiceCreationController.checkOutstandingCreditLimit(Trigger.new);
    }
}