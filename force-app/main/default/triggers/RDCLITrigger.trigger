trigger RDCLITrigger on Delivery_Challan_Line_Item__c (after insert) {
    if(trigger.isAfter && trigger.isInsert){
        RDCLITriggerHandler.changeStatusInWarehouse(trigger.new);
    }
}