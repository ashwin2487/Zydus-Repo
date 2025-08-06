public without sharing class AccountAccessUtil {
    public static Account getParentBusinessOwner(Id parentAccountId) {
        System.debug('Fetching Account for Id: ' + parentAccountId);
        List<Account> accList = [
            SELECT Id, Business_Owner__c, Business_Owner__r.Email, State__c, zydus_mapping__c, ParentId
            FROM Account 
            WHERE Id = :parentAccountId
            LIMIT 1
        ];
        if (accList.isEmpty()) {
            System.debug('No Account found for Id: ' + parentAccountId);
        }
        return accList.isEmpty() ? null : accList[0];
    }
    
}