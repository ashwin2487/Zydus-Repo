trigger SupplyOrderTrigger on Supply_Order__c (after insert) {
    if(trigger.isInsert && trigger.isAfter){
        SupplyOrderTriggerHandler.createDeliveryChallans(trigger.New);
    }
}