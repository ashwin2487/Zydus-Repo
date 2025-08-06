public without sharing class AccountHospitalSharingHandler {
    
    public static void createHospitalShare(List<Account_Hospital__c> newAccountHospitals) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> hospIds= new Set<Id>();
        set<Id> activeHospitalIds = new Set<Id>();
      	list<Hospital__c> insertedHospitalList = new List<Hospital__c>();
        for (Account_Hospital__c ah : newAccountHospitals) {
            accountIds.add(ah.Account__c);
            hospIds.add(ah.Hospital__c);
        }
        for(hospital__C curHospital : [select Id , Active__c , L1_Approved__c , L2_Approved__c from Hospital__c where ID IN : hospIds]){
            if(curHospital.Active__c == true && curHospital.L1_Approved__c == true && curHospital.L2_Approved__c == true){
                activeHospitalIds.add(curHospital.id);
            }else{
                return;
            }
               
        }
       
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, business_owner__c
            FROM Account
            WHERE Id IN :accountIds AND business_owner__c != null
        ]);
        
        Id whIds=[SELECT Id FROM Warehouse__C WHERE Hospital__c IN : activeHospitalIds LIMIT 1].Id;
        
        List<Hospital__Share> sharesToInsert = new List<Hospital__Share>();
        List<Warehouse__Share> sharesToInsertWH = new List<Warehouse__Share>();
        for (Account_Hospital__c ah : newAccountHospitals) {
            
            if (accountMap.containsKey(ah.Account__c)) {
                sharesToInsert.add(new Hospital__Share(
                    ParentId = ah.Hospital__c,
                    UserOrGroupId = accountMap.get(ah.Account__c).business_owner__c,
                    AccessLevel = 'Edit',
                    RowCause = Schema.Hospital__Share.RowCause.Manual
                ));
                
                sharesToInsertWH.add(new Warehouse__Share(
                    ParentId = whIds,
                    UserOrGroupId = accountMap.get(ah.Account__c).business_owner__c,
                    AccessLevel = 'Edit',
                    RowCause = Schema.Warehouse__Share.RowCause.Manual
                ));
            }
        }
        
        if (!sharesToInsert.isEmpty()) {
            try {   
                insert sharesToInsert;
            } catch (DmlException e) {
                System.debug('Error creating Hospital Share records: ' + e.getMessage());
            }
        }
        if (!sharesToInsertWH.isEmpty()) {
            try {
                insert sharesToInsertWH;
            } catch (DmlException e) {
                System.debug('Error creating Hospital Share records: ' + e.getMessage());
            }
        }
    }
}