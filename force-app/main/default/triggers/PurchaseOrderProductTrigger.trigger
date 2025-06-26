trigger PurchaseOrderProductTrigger on Purchase_Order_Product__c (before update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        PurchaseOrderProductHandler.validateUpdatePermission(Trigger.new, Trigger.oldMap);
    }
}