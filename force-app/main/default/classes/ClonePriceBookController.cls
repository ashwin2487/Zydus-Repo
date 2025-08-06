public class ClonePriceBookController {
    
    @AuraEnabled
    public static Id clonePriceBook(String originalPriceBookId, String newName, Date startDate, Date endDate, Boolean isActive, String dealer, String hospital, Id recordTypeId) {
        Zydus_Price_Book__c originalPB = [SELECT Id FROM Zydus_Price_Book__c WHERE Id = :originalPriceBookId LIMIT 1];

        Zydus_Price_Book__c newPB = new Zydus_Price_Book__c(
            Start_Date__c = startDate,
            End_Date__c = endDate,
            IsActive__c = isActive,
            Dealer_Name__c = String.isNotBlank(dealer) ? dealer : null,
            Hospital_Name__c = String.isNotBlank(hospital) ? hospital : null,
            RecordTypeId = recordTypeId
        );
        insert newPB;

        List<Zydus_Price_Book_Entry__c> originalEntries = [
            SELECT ARS_Minimum_Stock_Threshold__c,
                   Bill_Discount_Amount__c,
                   Brand__c,
                   Credit_Note_Amount__c,
                   Is_Active__c,
                   Minimum_Order_Quantity_MOQ__c,
                   RecordTypeId,
                   Unit_Price__c,
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
                RecordTypeId = entry.RecordTypeId,
                Unit_Price__c = entry.Unit_Price__c,
                Zydus_Product__c = entry.Zydus_Product__c,
                Zydus_Price_Book__c = newPB.Id
            ));
        }
        insert newEntries;
        return newPB.Id;
    }
}