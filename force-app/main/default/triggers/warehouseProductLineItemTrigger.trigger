trigger warehouseProductLineItemTrigger on Warehouse_Product_Line_Items__c (after insert, after Update) {
    if(trigger.isAfter){
        if(trigger.isInsert){
            warehouseProductLineItemTriggerHandler.warehouseProductUpdate(trigger.new , null);
        }else if(trigger.isUpdate){
            warehouseProductLineItemTriggerHandler.warehouseProductUpdate(trigger.new , trigger.old);
        }
    }
}