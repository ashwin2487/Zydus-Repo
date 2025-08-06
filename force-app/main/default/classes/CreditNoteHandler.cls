public class CreditNoteHandler {
    public static void shareCreditNotes(List<Credit_Note__c> notes) {
        Set<Id> invoiceIds = new Set<Id>();
        
        for (Credit_Note__c note : notes) {
            if (note.Invoice__c != null) {
                invoiceIds.add(note.Invoice__c);
            }
        }
        
        Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>(
            [SELECT Id, Consignee_Dealer__c, Consignor_Dealer__c 
             FROM Invoice__c 
             WHERE Id IN :invoiceIds]
        );
        
        Set<Id> accountIds = new Set<Id>();
        for (Invoice__c inv : invoiceMap.values()) {
            if (inv.Consignee_Dealer__c != null) accountIds.add(inv.Consignee_Dealer__c);
            if (inv.Consignor_Dealer__c != null) accountIds.add(inv.Consignor_Dealer__c);
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
        
        List<Credit_Note__Share> shares = new List<Credit_Note__Share>();
        
        for (Credit_Note__c note : notes) {
            Set<Id> userIdsToShare = new Set<Id>();
            Invoice__c inv = invoiceMap.get(note.Invoice__c);
            
            if (inv != null) {
                if (accountToOwner.containsKey(inv.Consignee_Dealer__c)) {
                    userIdsToShare.add(accountToOwner.get(inv.Consignee_Dealer__c));
                }
                if (accountToOwner.containsKey(inv.Consignor_Dealer__c)) {
                    userIdsToShare.add(accountToOwner.get(inv.Consignor_Dealer__c));
                }
            }
            
            for (Id userId : userIdsToShare) {
                Credit_Note__Share share = new Credit_Note__Share();
                share.ParentId = note.Id;
                share.UserOrGroupId = userId;
                share.AccessLevel = 'Edit';
                share.RowCause = Schema.Credit_Note__Share.RowCause.Manual;
                shares.add(share);
            }
        }
        
        if (!shares.isEmpty()) {
            Database.insert(shares, false);
        }
    }
}