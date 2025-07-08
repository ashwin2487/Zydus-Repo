public without sharing class AccountAccessUtil {
    public static Account getParentBusinessOwner(Id parentAccountId) {
        return [
            SELECT Id, Business_Owner__c, Business_Owner__r.Email , State__c, zydus_mapping__c
            FROM Account 
            WHERE Id = :parentAccountId 
            LIMIT 1
        ];
    }
}