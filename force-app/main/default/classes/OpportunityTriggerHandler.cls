public with sharing class OpportunityTriggerHandler {
    public static void linkContractToOppty(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        List<Opportunity> toUpdate = new List<Opportunity>();
        Set<Id> accountIds = new Set<Id>();

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);
            if (opp.StageName == 'Approve Purchase Order'
                && (oldOpp == null || oldOpp.StageName != 'Approve Purchase Order')
                && opp.ContractId == null) {
                accountIds.add(opp.AccountId);
                toUpdate.add(opp);
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
        List<Opportunity> updates = new List<Opportunity>();
        for (Opportunity opp : toUpdate) {
            Id contractId = accountToContractId.get(opp.AccountId);
            if (contractId != null) {
                Opportunity oppUpd = new Opportunity(
                    Id = opp.Id,
                    ContractId = contractId
                );
                updates.add(oppUpd);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}