trigger warehouseTrigger on Warehouse__c (after insert) {
    if(trigger.isAfter && trigger.isInsert){
        warehouseTriggerHandler.ShareHospitalWarehouse(trigger.new);
    }
}