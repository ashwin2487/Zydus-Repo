public without sharing class AccountHospitalSharingHandler {

    public static void createHospitalShare(List<Account_Hospital__c> newAccountHospitals) {
        Set<Id> accountIds = new Set<Id>();
        for (Account_Hospital__c ah : newAccountHospitals) {
            accountIds.add(ah.Account__c);
        }

        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, business_owner__c
            FROM Account
            WHERE Id IN :accountIds AND business_owner__c != null
        ]);

        List<Hospital__Share> sharesToInsert = new List<Hospital__Share>();
        for (Account_Hospital__c ah : newAccountHospitals) {
            if (accountMap.containsKey(ah.Account__c)) {
                sharesToInsert.add(new Hospital__Share(
                    ParentId = ah.Hospital__c,
                    UserOrGroupId = accountMap.get(ah.Account__c).business_owner__c,
                    AccessLevel = 'Edit',
                    RowCause = Schema.Hospital__Share.RowCause.Manual
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
    }
}