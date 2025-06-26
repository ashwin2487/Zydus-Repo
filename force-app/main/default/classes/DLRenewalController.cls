public with sharing class DLRenewalController {

    @AuraEnabled
    public static void updateAccountFields(Id accountId, String remarks, Date expiryDate, String option, String fileName, String base64FileData) {
        
        Account acc = [SELECT Id, DL_Active__c, Validity_of_Drug_Licence__c, DL_Expiry_Date_Remark__c FROM Account WHERE Id = :accountId LIMIT 1];
        
        String timestamp = DateTime.now().format();
        
        if (option == 'submittedForRenewal') {
            acc.DL_Active__c = true;
            acc.Validity_of_Drug_Licence__c = expiryDate;
            acc.DL_Expiry_Date_Remark__c = 'Submitted for Renewal at ' + timestamp + ': ' + remarks + '\n' + acc.DL_Expiry_Date_Remark__c + '\n';

        } else if (option == 'renewedDL') {
            acc.DL_Active__c = true;
            acc.Validity_of_Drug_Licence__c = expiryDate;

            acc.DL_Expiry_Date_Remark__c = 'Renewed DL at ' + timestamp + ': ' + remarks + '\n' + acc.DL_Expiry_Date_Remark__c;
        }

        update acc;

        if (fileName != null && base64FileData != null) {
            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName,
                VersionData = EncodingUtil.base64Decode(base64FileData),
                FirstPublishLocationId = accountId
            );
            insert cv; 
        }
    }    
}