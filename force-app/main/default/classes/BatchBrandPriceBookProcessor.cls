global class BatchBrandPriceBookProcessor implements Database.Batchable<SObject>, Database.Stateful {

    private List<Id> entryIds;

    public BatchBrandPriceBookProcessor(List<Id> entryIds) {
        this.entryIds = entryIds;
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, RecordTypeId, Zydus_Product__c, Zydus_Price_Book__c, Brand__c,
                   ARS_Minimum_Stock_Threshold__c, Bill_Discount_Amount__c, Credit_Note_Amount__c,
                   List_Price__c, Minimum_Order_Quantity_MOQ__c, Unit_Price__c, Use_Brand_Pricing__c,
                   Processed__c
            FROM Zydus_Price_Book_Entry__c
            WHERE Id IN :entryIds AND Processed__c = false
        ]);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<Zydus_Price_Book_Entry__c> typedScope = (List<Zydus_Price_Book_Entry__c>)scope;
        brandpricebookEntryTriggerHandler.addbrandProducts(typedScope);
    }

    global void finish(Database.BatchableContext BC) {}
}