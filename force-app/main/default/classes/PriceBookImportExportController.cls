public class PriceBookImportExportController {
    
    @AuraEnabled(cacheable=true)
    public static List<Zydus_Price_Book__c> getPriceBook(){
        return [SELECT Id, Name 
                FROM Zydus_Price_Book__c 
                WHERE IsActive__c = TRUE 
                AND OwnerId = :UserInfo.getUserId()];
    }
    
    @AuraEnabled
    public static List<Zydus_Price_Book_Entry__c> getAllDataToBeExport(List<String> PBIds){
        if (PBIds == null || PBIds.isEmpty()) {
            return new List<Zydus_Price_Book_Entry__c>();
        }
        try {
            return [SELECT Id, Zydus_Price_Book__c, Zydus_Price_Book__r.Name, Zydus_Product__r.Name, ARS_Minimum_Stock_Threshold__c,
                    Credit_Note_Amount__c, Unit_Price__c, Bill_Discount_Amount__c, Is_Active__c, Minimum_Order_Quantity_MOQ__c
                    FROM Zydus_Price_Book_Entry__c
                    WHERE Zydus_Price_Book__c IN :PBIds];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String updatePricebookEntries(String jsonString) {
        try {
            List<Zydus_Price_Book_Entry__c> entriesToUpdate = (List<Zydus_Price_Book_Entry__c>) JSON.deserialize(jsonString, List<Zydus_Price_Book_Entry__c>.class);

            if (entriesToUpdate != null && !entriesToUpdate.isEmpty()) {
                update entriesToUpdate;
                return 'Successfully updated ' + entriesToUpdate.size() + ' records.';
            } else {
                return 'No records were sent for update.';
            }
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred during the update: ' + e.getMessage());
        }
    }
}