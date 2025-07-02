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

        Set<Id> allSKUProductIds = new Set<Id>(skuProductIds);
        allSKUProductIds.addAll(allBrandProductIds);

        Map<String, Zydus_Price_Book_Entry__c> existingEntryMap = new Map<String, Zydus_Price_Book_Entry__c>();
        for (Zydus_Price_Book_Entry__c existing : [
            SELECT Id, Zydus_Product__c, Zydus_Price_Book__c,
                   ARS_Minimum_Stock_Threshold__c, Bill_Discount_Amount__c, Credit_Note_Amount__c,
                   List_Price__c, Minimum_Order_Quantity_MOQ__c, Unit_Price__c,
                   RecordTypeId, Use_Brand_Pricing__c
            FROM Zydus_Price_Book_Entry__c 
            WHERE Zydus_Product__c IN :allSKUProductIds AND Zydus_Price_Book__c IN :priceBookIds
        ]) {
            String key = existing.Zydus_Product__c + '-' + existing.Zydus_Price_Book__c;
            existingEntryMap.put(key, existing);
        }

        List<Zydus_Price_Book_Entry__c> toInsert = new List<Zydus_Price_Book_Entry__c>();
        List<Zydus_Price_Book_Entry__c> toUpdate = new List<Zydus_Price_Book_Entry__c>();
        List<Id> toDelete = new List<Id>();

        for (Zydus_Price_Book_Entry__c newEntry : brandEntriesMap.values()) {
            Set<Id> brandProducts = brandProductMap.get(newEntry.Brand__c);
            if (brandProducts != null) {
                for (Id productId : brandProducts) {
                    processEntry(productId, newEntry, existingEntryMap, toInsert, toUpdate, priceBookEntryRecordTypeMap.get('SKU'));
                }
                toDelete.add(newEntry.Id);
            }
        }

        for (Zydus_Price_Book_Entry__c skuEntry : skuEntriesList) {
            String key = skuEntry.Zydus_Product__c + '-' + skuEntry.Zydus_Price_Book__c;
            if (existingEntryMap.containsKey(key)) {
                Zydus_Price_Book_Entry__c existing = existingEntryMap.get(key);
                if (isUpdateRequired(existing, skuEntry)) {
                    updateEntry(existing, skuEntry, priceBookEntryRecordTypeMap.get('SKU'));
                    toUpdate.add(existing);
                    toDelete.add(skuEntry.Id);
                }
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!toDelete.isEmpty()) {
            List<Zydus_Price_Book_Entry__c> recordsToDelete = [
                SELECT Id FROM Zydus_Price_Book_Entry__c WHERE Id IN :toDelete
            ];
            delete recordsToDelete;
        }
    }

    private static void processEntry(Id productId, Zydus_Price_Book_Entry__c source,
                                     Map<String, Zydus_Price_Book_Entry__c> existingEntryMap,
                                     List<Zydus_Price_Book_Entry__c> toInsert,
                                     List<Zydus_Price_Book_Entry__c> toUpdate, Id recordTypeId) {
        String key = productId + '-' + source.Zydus_Price_Book__c;
        if (existingEntryMap.containsKey(key)) {
            Zydus_Price_Book_Entry__c upd = existingEntryMap.get(key);
            updateEntry(upd, source, recordTypeId);
            toUpdate.add(upd);
        } else {
            Zydus_Price_Book_Entry__c ins = createEntry(productId, source, recordTypeId);
            ins.Processed__c = true;
            toInsert.add(ins);
        }
    }

    private static void updateEntry(Zydus_Price_Book_Entry__c target, Zydus_Price_Book_Entry__c source, Id recordTypeId) {
        target.ARS_Minimum_Stock_Threshold__c = source.ARS_Minimum_Stock_Threshold__c;
        target.Bill_Discount_Amount__c = source.Bill_Discount_Amount__c;
        target.Credit_Note_Amount__c = source.Credit_Note_Amount__c;
        target.Is_Active__c = true;
        target.List_Price__c = source.List_Price__c;
        target.Minimum_Order_Quantity_MOQ__c = source.Minimum_Order_Quantity_MOQ__c;
        target.Unit_Price__c = source.Unit_Price__c;
        target.Use_Brand_Pricing__c = (recordTypeId == source.RecordTypeId);
        target.RecordTypeId = recordTypeId;
        target.Brand__c = source.Brand__c;
        target.Processed__c = true;
    }

    private static Zydus_Price_Book_Entry__c createEntry(Id productId, Zydus_Price_Book_Entry__c source, Id recordTypeId) {
        Zydus_Price_Book_Entry__c entry = new Zydus_Price_Book_Entry__c();
        entry.Zydus_Price_Book__c = source.Zydus_Price_Book__c;
        entry.Zydus_Product__c = productId;
        entry.Brand__c = source.Brand__c;
        entry.ARS_Minimum_Stock_Threshold__c = source.ARS_Minimum_Stock_Threshold__c;
        entry.Bill_Discount_Amount__c = source.Bill_Discount_Amount__c;
        entry.Credit_Note_Amount__c = source.Credit_Note_Amount__c;
        entry.Is_Active__c = true;
        entry.List_Price__c = source.List_Price__c;
        entry.Minimum_Order_Quantity_MOQ__c = source.Minimum_Order_Quantity_MOQ__c;
        entry.Unit_Price__c = source.Unit_Price__c;
        entry.RecordTypeId = recordTypeId;
        entry.Use_Brand_Pricing__c = (recordTypeId == source.RecordTypeId);
        entry.Processed__c = true;
        return entry;
    }

    private static Boolean isUpdateRequired(Zydus_Price_Book_Entry__c existing, Zydus_Price_Book_Entry__c incoming) {
        return 
            existing.ARS_Minimum_Stock_Threshold__c != incoming.ARS_Minimum_Stock_Threshold__c ||
            existing.Bill_Discount_Amount__c != incoming.Bill_Discount_Amount__c ||
            existing.Credit_Note_Amount__c != incoming.Credit_Note_Amount__c ||
            existing.List_Price__c != incoming.List_Price__c ||
            existing.Minimum_Order_Quantity_MOQ__c != incoming.Minimum_Order_Quantity_MOQ__c ||
            existing.Unit_Price__c != incoming.Unit_Price__c ||
            existing.RecordTypeId != incoming.RecordTypeId ||
            existing.Use_Brand_Pricing__c != incoming.Use_Brand_Pricing__c;
    }
}