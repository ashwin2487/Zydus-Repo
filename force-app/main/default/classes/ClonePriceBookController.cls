public class ClonePriceBookController {
    
    @AuraEnabled
    public static Id clonePriceBook(String originalPriceBookId, String newName, Date startDate, Date endDate, Boolean isActive) {
        Zydus_Price_Book__c originalPB = [SELECT Id FROM Zydus_Price_Book__c WHERE Id = :originalPriceBookId LIMIT 1];

        Zydus_Price_Book__c newPB = new Zydus_Price_Book__c(
            Price_Book_Name__c = newName,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            IsActive__c = isActive
        );
        insert newPB;

        List<Zydus_Price_Book_Entry__c> originalEntries = [
            SELECT ARS_Minimum_Stock_Threshold__c,
                   Bill_Discount_Amount__c,
                   Brand__c,
                   Credit_Note_Amount__c,
                   Is_Active__c,
                   Minimum_Order_Quantity_MOQ__c,
                   List_Price__c,
                   RecordTypeId,
                   Unit_Price__c,
                   Use_Brand_Pricing__c,
                   Zydus_Product__c
            FROM Zydus_Price_Book_Entry__c
            WHERE Zydus_Price_Book__c = :originalPriceBookId
        ];

        List<Zydus_Price_Book_Entry__c> newEntries = new List<Zydus_Price_Book_Entry__c>();
        
        for (Zydus_Price_Book_Entry__c entry : originalEntries) {
            newEntries.add(new Zydus_Price_Book_Entry__c(
                ARS_Minimum_Stock_Threshold__c = entry.ARS_Minimum_Stock_Threshold__c,
                Bill_Discount_Amount__c = entry.Bill_Discount_Amount__c,
                Brand__c = entry.Brand__c,
                Credit_Note_Amount__c = entry.Credit_Note_Amount__c,
                Is_Active__c = entry.Is_Active__c,
                Minimum_Order_Quantity_MOQ__c = entry.Minimum_Order_Quantity_MOQ__c,
                List_Price__c = entry.List_Price__c,
                RecordTypeId = entry.RecordTypeId,
                Unit_Price__c = entry.Unit_Price__c,
                Use_Brand_Pricing__c = entry.Use_Brand_Pricing__c,
                Zydus_Product__c = entry.Zydus_Product__c,
                Zydus_Price_Book__c = newPB.Id
            ));
        }
        insert newEntries;
        return newPB.Id;
    }
}