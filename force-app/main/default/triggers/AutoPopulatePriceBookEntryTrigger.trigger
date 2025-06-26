trigger AutoPopulatePriceBookEntryTrigger on Zydus_Price_Book_Entry__c (before insert) {
    if(trigger.isInsert && trigger.isBefore){
        AutoPopulatePriceBookEntryTriggerhandler.CreatePriceBookEntry(trigger.New);
    }
}