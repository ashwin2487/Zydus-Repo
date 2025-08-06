trigger supplyOrderTrigger on Supply_Order__c (after update, after insert) {
    if(trigger.isAfter && trigger.isUpdate){
            supplyOrderTriggerHandler.creditNotesToInsert(trigger.New, trigger.oldMap);
    }
    if(trigger.isAfter && trigger.isInsert){
        supplyOrderTriggerHandler.shareSupplyOrder(trigger.New);
    }
}