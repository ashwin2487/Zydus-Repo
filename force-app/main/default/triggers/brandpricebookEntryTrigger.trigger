trigger brandpricebookEntryTrigger on Zydus_Price_Book_Entry__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        if (!TriggerControl.hasEnqueuedBrandBatch) {
            List<Id> entryIds = new List<Id>();
            for (Zydus_Price_Book_Entry__c entry : Trigger.new) {
                if (entry.Processed__c != true) {
                    entryIds.add(entry.Id);
                }
            }

            if (!entryIds.isEmpty()) {
                System.enqueueJob(new EnqueueBrandPriceBookBatch(entryIds));
                TriggerControl.hasEnqueuedBrandBatch = true;
            }
        }
    }
}