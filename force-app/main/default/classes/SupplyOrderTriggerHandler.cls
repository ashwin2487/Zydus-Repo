public class supplyOrderTriggerHandler {
    
    public static void creditNotesToInsert(List<Supply_Order__c> newRSORecords, Map<Id,Supply_Order__c> oldMap) {
        Id recordTypeId =[select Id from RecordType where SobjectType = 'Credit_Note__c' and DeveloperName = 'RSO'].Id;
        Set<Id> recordTypeIds = new Set<Id>();
        for (Supply_Order__c so : newRSORecords) {
            if (so.RecordTypeId != null) {
                recordTypeIds.add(so.RecordTypeId);
            }
        }
        
        Map<Id, String> recordTypeMap = new Map<Id, String>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE Id IN :recordTypeIds
            AND SObjectType = 'Supply_Order__c'
        ]) {
            recordTypeMap.put(rt.Id, rt.DeveloperName);
        }
        
        List<Credit_Note__c> creditNotesToInsert = new List<Credit_Note__c>();
        
        for (Supply_Order__c so : newRSORecords) {
            if (recordTypeMap.get(so.RecordTypeId) == 'RSO' && recordTypeMap.get(so.RecordTypeId) != 'SO') {
                Supply_Order__c oldSO = oldMap.get(so.Id);
                if (oldSO != null && (so.Net_Amount__c != oldSO.Net_Amount__c ||
                                      so.Total_CGST__c != oldSO.Total_CGST__c || so.Total_IGST__c != oldSO.Total_IGST__c || so.Total_SGST__c != oldSO.Total_SGST__c)) {
                                          
                                          creditNotesToInsert.add(new Credit_Note__c(
                                              Supply_Order__c = so.Id,
                                              Amount__c = so.Net_Amount__c,
                                              Date__c = Date.today(),
                                              Account__c = so.Consignee_Distributor__c,
                                              RecordTypeId = recordTypeId
                                          ));
                                      }
            }
        }
        
        if (!creditNotesToInsert.isEmpty()) {
            try {
                insert creditNotesToInsert;
            } catch (DmlException e) {
                System.debug('Error inserting Credit Notes: ' + e.getMessage());
                for (Integer i = 0; i < e.getNumDml(); i++) {
                    System.debug('Record causing error: ' + creditNotesToInsert[i]);
                    System.debug('Error message: ' + e.getDmlMessage(i));
                }
            }
            
        }
    }
    public static void shareSupplyOrder(List<Supply_Order__c> newRecord) {
        Set<Id> accountIds = new Set<Id>();
        
        for (Supply_Order__c so : newRecord) {
            if (so.Consignee_Distributor__c != null) accountIds.add(so.Consignee_Distributor__c);
            if (so.Consignor_Distributor__c != null) accountIds.add(so.Consignor_Distributor__c);
        }
        
        Map<Id, Id> accountToOwner = new Map<Id, Id>();
        for (Account acc : [
            SELECT Id, Business_owner__c 
            FROM Account 
            WHERE Id IN :accountIds
        ]) {
            if (acc.Business_owner__c != null) {
                accountToOwner.put(acc.Id, acc.Business_owner__c);
            }
        }
        
        List<Supply_Order__Share> shares = new List<Supply_Order__Share>();
        
        for (Supply_Order__c so : newRecord) {
            Set<Id> userIdsToShare = new Set<Id>();
            
            if (accountToOwner.containsKey(so.Consignee_Distributor__c)) {
                userIdsToShare.add(accountToOwner.get(so.Consignee_Distributor__c));
            }
            
            if (accountToOwner.containsKey(so.Consignor_Distributor__c)) {
                userIdsToShare.add(accountToOwner.get(so.Consignor_Distributor__c));
            }
            
            for (Id userId : userIdsToShare) {
                Supply_Order__Share share = new Supply_Order__Share();
                share.ParentId = so.Id;
                share.UserOrGroupId = userId;
                share.AccessLevel = 'Edit';
                share.RowCause = Schema.Supply_Order__Share.RowCause.Manual;
                shares.add(share);
            }
        }
        
        if (!shares.isEmpty()) {
            Database.insert(shares, false);
        }
    }
    
}