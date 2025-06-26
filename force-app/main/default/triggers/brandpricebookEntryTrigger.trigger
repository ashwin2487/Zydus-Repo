trigger brandpricebookEntryTrigger on Zydus_Price_Book_Entry__c (After insert) {
    if(Trigger.isInsert && Trigger.isAfter){
        brandpricebookEntryTriggerHandler.addbrandProducts(trigger.new);
    }
}