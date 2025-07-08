trigger SoToCNtrigger on Supply_Order__c (after update, after insert) {
    if(trigger.isAfter && trigger.isUpdate){
            SoToCNtriggerhandler.creditNotesToInsert(trigger.New, trigger.oldMap);
    }
}