public without sharing class DeliveryChallanTriggerHandler {
    public static void shareChallans(List<Delivery_Challan__c> challans) {
        Set<Id> accountIds = new Set<Id>();
        
        for (Delivery_Challan__c dc : challans) {
            if (dc.Consignee_Distributor__c != null) accountIds.add(dc.Consignee_Distributor__c);
            if (dc.Consignor_Distributor__c != null) accountIds.add(dc.Consignor_Distributor__c);
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
        
        List<Delivery_Challan__Share> shares = new List<Delivery_Challan__Share>();
        
        for (Delivery_Challan__c dc : challans) {
            Set<Id> userIdsToShare = new Set<Id>();
            
            if (accountToOwner.containsKey(dc.Consignee_Distributor__c)) {
                userIdsToShare.add(accountToOwner.get(dc.Consignee_Distributor__c));
            }
            
            if (accountToOwner.containsKey(dc.Consignor_Distributor__c)) {
                userIdsToShare.add(accountToOwner.get(dc.Consignor_Distributor__c));
            }
            
            for (Id userId : userIdsToShare) {
                Delivery_Challan__Share share = new Delivery_Challan__Share();
                share.ParentId = dc.Id;
                share.UserOrGroupId = userId;
                share.AccessLevel = 'Edit';
                share.RowCause = Schema.Delivery_Challan__Share.RowCause.Manual;
                shares.add(share);
            }
        }
        
        if (!shares.isEmpty()) {
            Database.insert(shares, false);
        }
    }
    
}