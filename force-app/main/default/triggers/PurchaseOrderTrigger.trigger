trigger PurchaseOrderTrigger on Purchase_Order__c (after insert , before update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        PurchaseOrderTriggerHandler.linkContractToPurchaseOrder(Trigger.new, Trigger.oldMap);
    }
}