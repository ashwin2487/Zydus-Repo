public class SoToCNtriggerhandler {
    
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
}