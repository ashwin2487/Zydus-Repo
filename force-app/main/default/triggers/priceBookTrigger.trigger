trigger priceBookTrigger on Zydus_Price_Book__c (before insert, after insert) {
    if (Trigger.isInsert && Trigger.isBefore) {
        priceBookTriggerHandler.PBNameUpdate(Trigger.new);
    }
    if (Trigger.isInsert && Trigger.isAfter) {
        priceBookTriggerHandler.shareWithSuperDistributor(Trigger.new);
    }
}