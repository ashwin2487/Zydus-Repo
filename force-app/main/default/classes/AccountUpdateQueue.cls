public with sharing class AccountUpdateQueue implements Queueable {
    private Map<Id, Id> accountUserMap;
    
    public AccountUpdateQueue(Map<Id, Id> accountUserMap) {
        this.accountUserMap = accountUserMap;
    }
    
    public void execute(QueueableContext context) {
        Map<Id, Id> accountToParentIdMap = new Map<Id, Id>();
        for (Account acc : [SELECT Id, ParentId FROM Account WHERE Id IN :accountUserMap.keySet()]) {
            if (acc.ParentId != null) {
                accountToParentIdMap.put(acc.Id, acc.ParentId);
            }
        }
        
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Id accId : accountUserMap.keySet()) {
            if (accId != null) {
                accountsToUpdate.add(new Account(
                    Id = accId,
                    Business_Owner__c = accountUserMap.get(accId),
                    OwnerId = accountUserMap.get(accId)
                ));
            }
        }
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
            accountsToUpdate = [
                SELECT Id, Business_Owner__c, ParentId, OwnerId, Hospital_Mapping__c 
                FROM Account 
                WHERE Id = :accountsToUpdate[0].Id
            ];
        }
        
        List<Warehouse__c> toupdate = new List<Warehouse__c>();
        for (Warehouse__c curWarehouse : [
            SELECT Id, OwnerId, Account__c 
            FROM Warehouse__c 
            WHERE Account__c IN :accountUserMap.keySet()
        ]) {
            curWarehouse.OwnerId = accountUserMap.get(curWarehouse.Account__c);
            toupdate.add(curWarehouse);
        }
        
        if (!toupdate.isEmpty()) {
            update toupdate;
        }
        List<Account_Hospital__c> junctionsToInsert = new List<Account_Hospital__c>();
        for (Account acc : [
            SELECT Id, Hospital_Mapping__c 
            FROM Account 
            WHERE Id IN :accountUserMap.keySet()
        ]) {
            if (String.isNotBlank(acc.Hospital_Mapping__c)) {
                List<String> hospPairs = acc.Hospital_Mapping__c.split(',');
                for (String pair : hospPairs) {
                    List<String> parts = pair.split('\\|');
                    if (parts.size() == 2) {
                        junctionsToInsert.add(new Account_Hospital__c(
                            Account__c = acc.Id,
                            Hospital__c = parts[0]
                        ));
                    }
                }
            }
        }
        
        if (!junctionsToInsert.isEmpty()) {
            insert junctionsToInsert;
        }
        
        if (!accountUserMap.isEmpty()) {
            System.enqueueJob(new FirstOrderCreationQueue(new List<Id>(accountUserMap.keySet())));
        }
    }
}