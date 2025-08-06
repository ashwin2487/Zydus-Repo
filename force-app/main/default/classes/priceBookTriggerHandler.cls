public class priceBookTriggerHandler {
    public static void PBNameUpdate(List<Zydus_Price_Book__c> newRecord){
        Account currUserAcc;
        try {
            currUserAcc = [SELECT Name FROM Account WHERE Business_Owner__c = :UserInfo.getUserId() LIMIT 1];
        } catch (QueryException e) {
            newRecord[0].addError('The current user is not associated with a Business Owner Account.');
            return;
        }
        
        Map<Id, RecordType> rtMap = new Map<Id, RecordType>(
            [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Zydus_Price_Book__c']
        );
        
        for (Zydus_Price_Book__c pb : newRecord) {
            String recordTypeName = rtMap.get(pb.RecordTypeId)?.Name;
            String todayDateStr = String.valueOf(Date.today());
            String newName;
            
            if (recordTypeName == 'Dealer' && pb.Dealer_Name__c != null) {
                newName = pb.Dealer_Name__c.replaceAll('\\s+', '') + '_' + currUserAcc.Name.replaceAll('\\s+', '') + '_' + todayDateStr;
            } else if (recordTypeName == 'Hospital' && pb.Hospital_Name__c != null) {
                newName = pb.Hospital_Name__c.replaceAll('\\s+', '') + '_' + currUserAcc.Name.replaceAll('\\s+', '') + '_' + todayDateStr;
            }
            
            if (newName != null) {
                pb.Name = newName;
            }
        }
    }
    public static void shareWithSuperDistributor(List<Zydus_Price_Book__c> newPriceBooks) {
        Id currentUserId = UserInfo.getUserId();
        User userRecord = [SELECT Id, UserRole.Name
                           FROM User
                           WHERE Id = :currentUserId
                           LIMIT 1
                          ];
        Account userAccount = [SELECT Id, ParentId, Business_owner__c
                               FROM Account
                               WHERE Business_owner__c = :currentUserId
                               LIMIT 1
                              ];
        if (userAccount == null) {
            System.debug('No account found for the logged-in user.');
            return;
        }
        Account superDistributorAccount = null;
        if (userRecord.UserRole.Name == 'Sub Distributor') {
            if (userAccount.ParentId != null) {
                Account distributorAccount = [
                    SELECT Id, ParentId
                    FROM Account
                    WHERE Id = :userAccount.ParentId
                    LIMIT 1
                ];
                if (distributorAccount != null && distributorAccount.ParentId != null) {
                    superDistributorAccount = [
                        SELECT Id, Business_owner__c
                        FROM Account
                        WHERE Id = :distributorAccount.ParentId
                        LIMIT 1
                    ];
                }
            }
        } else if (userRecord.UserRole.Name == 'Distributor') {
            if (userAccount.ParentId != null) {
                superDistributorAccount = [
                    SELECT Id, Business_owner__c
                    FROM Account
                    WHERE Id = :userAccount.ParentId
                    LIMIT 1
                ];
            }
        }
        
        if (superDistributorAccount == null) {
            System.debug('Super Distributor account not found.');
            return;
        }
        Id superDistributorUserId = superDistributorAccount.Business_owner__c;
        if (superDistributorUserId == null) {
            System.debug('No Business Owner found for Super Distributor.');
            return;
        }
        List<Zydus_Price_Book__Share> sharesToInsert = new List<Zydus_Price_Book__Share>();
        
        for (Zydus_Price_Book__c pb : newPriceBooks) {
            sharesToInsert.add(new Zydus_Price_Book__Share(
                ParentId = pb.Id,
                UserOrGroupId = superDistributorUserId,
                AccessLevel = 'Edit', 
                RowCause = Schema.Zydus_Price_Book__Share.RowCause.Manual
            ));
        }
        
        if (!sharesToInsert.isEmpty()) {
            try {
                insert sharesToInsert;
            } catch (DmlException e) {
                System.debug('Error sharing Price Book with Super Distributor: ' + e.getMessage());
            }
        }
    }
}