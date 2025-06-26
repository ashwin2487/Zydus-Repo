public with sharing class PurchaseOrderTriggerHandler {
    public static void linkContractToPurchaseOrder(List<Purchase_Order__c> newPOs, Map<Id, Purchase_Order__c> oldPOMAP) {
        List<Purchase_Order__c> toUpdate = new List<Purchase_Order__c>();
        Set<Id> accountIds = new Set<Id>();

        for (Purchase_Order__c po : newPOs) {
            Purchase_Order__c oldPO = oldPOMAP.get(po.Id);
            if (po.StageName__c == 'Approve Purchase Order'
                && (oldPO == null || oldPO.StageName__c != 'Approve Purchase Order')
                && po.ContractId__c == null) {
                accountIds.add(po.Account__c);
                toUpdate.add(po);
            }
        }

        if (toUpdate.isEmpty() || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Id> accountToContractId = new Map<Id, Id>();
        Map<Id, Id> accountToParent = new Map<Id, Id>();

        for (Account acc : [
            SELECT Id, ParentId
            FROM Account
            WHERE Id IN :accountIds
        ]) {
            accountToParent.put(acc.Id, acc.ParentId);
        }

        for (Contract con : [
            SELECT Id, AccountId, Contracted_Account__c
            FROM Contract
            WHERE AccountId IN :accountIds
              AND Status = 'Activated'
        ]) {
            Id parentId = accountToParent.get(con.AccountId);
            if (parentId != null && con.Contracted_Account__c == parentId) {
                accountToContractId.put(con.AccountId, con.Id);
            }
        }

        List<Purchase_Order__c> updates = new List<Purchase_Order__c>();

        for (Purchase_Order__c po : toUpdate) {
            Id contractId = accountToContractId.get(po.Account__c);
            if (contractId != null) {
                Purchase_Order__c poUpd = new Purchase_Order__c(
                    Id = po.Id,
                    ContractId__c = contractId
                );
                updates.add(poUpd);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}