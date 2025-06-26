public with sharing class OpportunityController {
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(Id accountId) {
        return [SELECT Id, Name, StageName, AccountId FROM Opportunity WHERE AccountId = :accountId AND StageName != 'Closed Won'];
    }

    @AuraEnabled
    public static void approveOpportunity(Id opportunityId) {
        Opportunity opp = [SELECT Id, StageName, AccountId FROM Opportunity WHERE Id = :opportunityId];
        opp.StageName = 'Closed Won';
        update opp;

        Order newOrder = new Order(
            OpportunityId = opp.Id,
            AccountId = opp.AccountId,
            Status = 'Draft',
            EffectiveDate = Date.today()
        );
        insert newOrder;
    }

    @AuraEnabled
    public static List<OpportunityLineItem> getOpportunityLineItems(Id opportunityId) {
        return [SELECT Id, Quantity, UnitPrice, TotalPrice, PricebookEntryId FROM OpportunityLineItem WHERE OpportunityId = :opportunityId];
    }

    @AuraEnabled
    public static void saveOpportunityLineItems(List<OpportunityLineItem> items) {
        update items;
    }
}