trigger SoToCNtrigger on Supply_Order__c (after update) {
    if(trigger.isAfter && trigger.isUpdate){
            SoToCNtriggerhandler.creditNotesToInsert(trigger.New, trigger.oldMap);
    }
}