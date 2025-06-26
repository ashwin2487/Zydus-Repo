public class AccountSharingHandler {
    
    public static void shareWithBusinessOwners(List<Account> accounts) {
        List<AccountShare> shares = new List<AccountShare>();
        
        Set<Id> parentAccountIds = new Set<Id>();
        for (Account acc : accounts) {
            if (acc.ParentId != null) {
                parentAccountIds.add(acc.ParentId);
            }
        }
        
        Map<Id, Account> parentAccountsMap = new Map<Id, Account>(
            [SELECT Id, Business_Owner__c, OwnerId FROM Account WHERE Id IN :parentAccountIds]
        );
        
        for (Account acc : accounts) {
            if (acc.Business_Owner__c != null && acc.Business_Owner__c != acc.OwnerId) {
                AccountShare share = new AccountShare();
                share.AccountId = acc.Id;
                share.UserOrGroupId = acc.Business_Owner__c;
                share.AccountAccessLevel = 'Edit';
                share.OpportunityAccessLevel = 'Edit';
                share.RowCause = Schema.AccountShare.RowCause.Manual;
                shares.add(share);
            }
            
            // Share with the parent account's Business Owner
            if (acc.ParentId != null && parentAccountsMap.containsKey(acc.ParentId)) {
                Id parentOwner = parentAccountsMap.get(acc.ParentId).Business_Owner__c;
                if (parentOwner != null && parentOwner != acc.OwnerId) {
                    AccountShare parentShare = new AccountShare();
                    parentShare.AccountId = acc.Id;
                    parentShare.UserOrGroupId = parentOwner;
                    parentShare.AccountAccessLevel = 'Edit';
                    parentShare.OpportunityAccessLevel = 'Edit';
                    parentShare.RowCause = Schema.AccountShare.RowCause.Manual;
                    shares.add(parentShare);
                }
            }
        }
        
        if (!shares.isEmpty()) {
            insert shares;
        }
    }
    
}