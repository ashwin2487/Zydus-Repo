public class AutoPopulatePriceBookEntryTriggerhandler {

    public static void CreatePriceBookEntry(List<Zydus_Price_Book_Entry__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) return;

        Set<Id> productIds = new Set<Id>();
        
        for (Zydus_Price_Book_Entry__c rec : newRecords) {
            if (rec.Zydus_Product__c != null) {
                productIds.add(rec.Zydus_Product__c);
            }
        }

        // Query product data
        Map<Id, Zydus_Product__c> productMap = new Map<Id, Zydus_Product__c>(
            [SELECT Id, ARS_Minimum_Stock_Threshold__c, Bill_Discount_Amount__c,
                    Credit_Note_Amount__c, List_Price__c, Unit_Price__c,
                    Minimum_Order_Quantity_MOQ__c, IsActive__c, Brand__c
             FROM Zydus_Product__c
             WHERE Id IN :productIds]
        );

        // Prepare Brand Ids only if needed
        Set<Id> brandIds = new Set<Id>();
        for (Zydus_Price_Book_Entry__c record : newRecords) {
            if (record.Use_Brand_Pricing__c) {
                Zydus_Product__c product = productMap.get(record.Zydus_Product__c);
                if (product != null && product.Brand__c != null) {
                    brandIds.add(product.Brand__c);
                }
            }
        }

        // Query brands if required
        Map<Id, Brand__c> brandMap = brandIds.isEmpty() ? new Map<Id, Brand__c>() :
            new Map<Id, Brand__c>(
                [SELECT Id, ARS_Minimum_Stock_Threshold__c, Bill_Discount_Amount__c,
                        Credit_Note_Amount__c, List_Price__c, Unit_Price__c,
                        Minimum_Order_Quantity_MOQ__c
                 FROM Brand__c
                 WHERE Id IN :brandIds]
            );

        // Populate fields directly on Trigger.new records
        for (Zydus_Price_Book_Entry__c record : newRecords) {
            if (record.Zydus_Product__c == null) continue;

            Zydus_Product__c product = productMap.get(record.Zydus_Product__c);
            if (product == null) continue;

            // Validate active product
            if (!product.IsActive__c) {
                record.addError('Please check if the product is active, if not kindly activate the product');
                continue;
            }

            if (record.Is_Active__c) {
                if (!record.Use_Brand_Pricing__c) {
                    // Product-level pricing
                    record.Bill_Discount_Amount__c = product.Bill_Discount_Amount__c;
                    record.Credit_Note_Amount__c = product.Credit_Note_Amount__c;
                    record.List_Price__c = product.List_Price__c;
                    record.Unit_Price__c = product.Unit_Price__c;
                    record.Minimum_Order_Quantity_MOQ__c = product.Minimum_Order_Quantity_MOQ__c;
                    record.ARS_Minimum_Stock_Threshold__c = product.ARS_Minimum_Stock_Threshold__c;
                } else if (product.Brand__c != null) {
                    // Brand-level pricing
                    Brand__c brand = brandMap.get(product.Brand__c);
                    if (brand != null) {
                        record.Bill_Discount_Amount__c = brand.Bill_Discount_Amount__c;
                        record.Credit_Note_Amount__c = brand.Credit_Note_Amount__c;
                        record.List_Price__c = brand.List_Price__c;
                        record.Unit_Price__c = brand.Unit_Price__c;
                        record.Minimum_Order_Quantity_MOQ__c = brand.Minimum_Order_Quantity_MOQ__c;
                        record.ARS_Minimum_Stock_Threshold__c = brand.ARS_Minimum_Stock_Threshold__c;
                    }
                }
            }
        }
    }
}