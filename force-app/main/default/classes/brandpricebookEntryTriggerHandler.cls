public class brandpricebookEntryTriggerHandler {
    private static Boolean hasRun = false;

    public static void addbrandProducts(List<Zydus_Price_Book_Entry__c> newRecords) {
        if (hasRun) return;
        hasRun = true;

        Map<String, Id> priceBookEntryRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Zydus_Price_Book_Entry__c']) {
            priceBookEntryRecordTypeMap.put(rt.Name, rt.Id);
        }

        Map<Id, Zydus_Price_Book_Entry__c> brandEntriesMap = new Map<Id, Zydus_Price_Book_Entry__c>();
        List<Zydus_Price_Book_Entry__c> skuEntriesList = new List<Zydus_Price_Book_Entry__c>();

        Set<Id> brandIds = new Set<Id>();
        Set<Id> priceBookIds = new Set<Id>();
        Set<Id> skuProductIds = new Set<Id>();

        for (Zydus_Price_Book_Entry__c entry : newRecords) {
            if (entry.Processed__c == true) continue;
            if (entry.RecordTypeId == priceBookEntryRecordTypeMap.get('Brand')) {
                brandEntriesMap.put(entry.Id, entry);
                brandIds.add(entry.Brand__c);
                priceBookIds.add(entry.Zydus_Price_Book__c);
            } else if (entry.RecordTypeId == priceBookEntryRecordTypeMap.get('SKU')) {
                skuEntriesList.add(entry);
                if (entry.Zydus_Product__c != null) {
                    skuProductIds.add(entry.Zydus_Product__c);
                    priceBookIds.add(entry.Zydus_Price_Book__c);
                }
            }
        }

        // Get all active products for the brand(s)
        Map<Id, Set<Id>> brandProductMap = new Map<Id, Set<Id>>();
        Set<Id> allBrandProductIds = new Set<Id>();
        for (Zydus_Product__c prod : [
            SELECT Id, Brand__c
            FROM Zydus_Product__c
            WHERE IsActive__c = true AND Brand__c IN :brandIds
        ]) {
            if (!brandProductMap.containsKey(prod.Brand__c)) {
                brandProductMap.put(prod.Brand__c, new Set<Id>());
            }
            brandProductMap.get(prod.Brand__c).add(prod.Id);
            allBrandProductIds.add(prod.Id);
        }

        List<Id> toDelete = new List<Id>();
        List<Zydus_Price_Book_Entry__c> toInsert = new List<Zydus_Price_Book_Entry__c>();

        for (Zydus_Price_Book_Entry__c brandEntry : brandEntriesMap.values()) {
            Set<Id> brandProducts = brandProductMap.get(brandEntry.Brand__c);
            if (brandProducts == null) continue;

            List<Zydus_Price_Book_Entry__c> existingEntries = [
                SELECT Id FROM Zydus_Price_Book_Entry__c
                WHERE Zydus_Product__c IN :brandProducts
                AND Zydus_Price_Book__c = :brandEntry.Zydus_Price_Book__c
            ];
            for (Zydus_Price_Book_Entry__c existing : existingEntries) {
                toDelete.add(existing.Id);
            }

            for (Id prodId : brandProducts) {
                Zydus_Price_Book_Entry__c newEntry = new Zydus_Price_Book_Entry__c();
                newEntry.Zydus_Price_Book__c = brandEntry.Zydus_Price_Book__c;
                newEntry.Zydus_Product__c = prodId;
                newEntry.Brand__c = brandEntry.Brand__c;
                newEntry.ARS_Minimum_Stock_Threshold__c = brandEntry.ARS_Minimum_Stock_Threshold__c;
                newEntry.Bill_Discount_Amount__c = brandEntry.Bill_Discount_Amount__c;
                newEntry.Credit_Note_Amount__c = brandEntry.Credit_Note_Amount__c;
                newEntry.Is_Active__c = true;
                newEntry.Minimum_Order_Quantity_MOQ__c = brandEntry.Minimum_Order_Quantity_MOQ__c;
                newEntry.Unit_Price__c = brandEntry.Unit_Price__c;
                newEntry.RecordTypeId = priceBookEntryRecordTypeMap.get('Brand');
                newEntry.Processed__c = true;
                toInsert.add(newEntry);
            }

            toDelete.add(brandEntry.Id);
        }

        for (Zydus_Price_Book_Entry__c skuEntry : skuEntriesList) {
            if (skuEntry.Zydus_Product__c == null) continue;

            List<Zydus_Price_Book_Entry__c> existingSKUEntries = [
                SELECT Id FROM Zydus_Price_Book_Entry__c
                WHERE Zydus_Product__c = :skuEntry.Zydus_Product__c
                AND Zydus_Price_Book__c = :skuEntry.Zydus_Price_Book__c
            ];
            for (Zydus_Price_Book_Entry__c existing : existingSKUEntries) {
                toDelete.add(existing.Id);
            }

            Zydus_Price_Book_Entry__c newSKUEntry = new Zydus_Price_Book_Entry__c();
            newSKUEntry.Zydus_Price_Book__c = skuEntry.Zydus_Price_Book__c;
            newSKUEntry.Zydus_Product__c = skuEntry.Zydus_Product__c;
            newSKUEntry.Brand__c = skuEntry.Brand__c;
            newSKUEntry.ARS_Minimum_Stock_Threshold__c = skuEntry.ARS_Minimum_Stock_Threshold__c;
            newSKUEntry.Bill_Discount_Amount__c = skuEntry.Bill_Discount_Amount__c;
            newSKUEntry.Credit_Note_Amount__c = skuEntry.Credit_Note_Amount__c;
            newSKUEntry.Is_Active__c = true;
            newSKUEntry.Minimum_Order_Quantity_MOQ__c = skuEntry.Minimum_Order_Quantity_MOQ__c;
            newSKUEntry.Unit_Price__c = skuEntry.Unit_Price__c;
            newSKUEntry.RecordTypeId = priceBookEntryRecordTypeMap.get('SKU');
            newSKUEntry.Processed__c = true;
            toInsert.add(newSKUEntry);

            toDelete.add(skuEntry.Id);
        }

        if (!toDelete.isEmpty()) {
            List<Zydus_Price_Book_Entry__c> recordsToDelete = [
                SELECT Id FROM Zydus_Price_Book_Entry__c WHERE Id IN :toDelete
            ];
            delete recordsToDelete;
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }
}