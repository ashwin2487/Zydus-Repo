public with sharing class onboardingController {
    
    private static Map<String, Id> recordTypeMap;
    
    static {
        recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account']) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDistributorsBySuper(Id superDistributorId) {
        List<Account> distributors = [
            SELECT Id, Name FROM Account
            WHERE ParentId = :superDistributorId AND Distributor_Type__c = 'Distributor'
        ];
        return buildSelectOptions(distributors);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSubDistributorsByDistributor(Id distributorId) {
        List<Account> subDistributors = [
            SELECT Id, Name FROM Account
            WHERE ParentId = :distributorId AND Distributor_Type__c = 'Sub Distributor'
        ];
        return buildSelectOptions(subDistributors);
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchUserDistributorHierarchy(Id userId) {
        Map<String, Object> result = new Map<String, Object>();
        
        User currentUser = [
            SELECT Id, Profile.Name, UserRole.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        // System Admin check
        Boolean isAdmin = currentUser.Profile.Name == 'System Administrator';
        
        if (isAdmin) {
            // Admin: Show all Super Distributors as options
            List<Account> superDistributors = [
                SELECT Id, Name FROM Account
                WHERE Distributor_Type__c = 'Super Distributor'
            ];
            result.put('superDistributorOptions', buildSelectOptions(superDistributors));
            result.put('role', 'System Admin');
            return result;
        }
        
        // Regular user — fetch account
        List<Account> userAccounts = [
            SELECT Id, Name, Distributor_Type__c, ParentId, Parent.Name, Business_Owner__c
            FROM Account
            WHERE Business_Owner__c = :userId
            LIMIT 1
        ];
        
        if (userAccounts.isEmpty()) return result;
        
        Account userAccount = userAccounts[0];
        String role = userAccount.Distributor_Type__c;
        result.put('role', role);
        
        if (role == 'Super Distributor') {
            result.put('superDistributor', userAccount);
            
            // Fetch Distributors
            List<Account> distributors = [
                SELECT Id, Name FROM Account
                WHERE ParentId = :userAccount.Id AND Distributor_Type__c = 'Distributor'
            ];
            result.put('distributorOptions', buildSelectOptions(distributors));
            
        } else if (role == 'Distributor') {
            result.put('distributor', userAccount);
            if (userAccount.ParentId != null) {
                result.put('superDistributor', userAccount.Parent);
            }
            
            // Fetch Sub Distributors
            List<Account> subDistributors = [
                SELECT Id, Name FROM Account
                WHERE ParentId = :userAccount.Id AND Distributor_Type__c = 'Sub Distributor'
            ];
            result.put('subDistributorOptions', buildSelectOptions(subDistributors));
            
        } else if (role == 'Sub Distributor') {
            result.put('subDistributor', userAccount);
            if (userAccount.ParentId != null) {
                Account distributor = [
                    SELECT Id, Name, ParentId, Parent.Name FROM Account
                    WHERE Id = :userAccount.ParentId
                    LIMIT 1
                ];
                result.put('distributor', distributor);
                if (distributor.ParentId != null) {
                    result.put('superDistributor', distributor.Parent);
                }
            }
        }
        
        return result;
    }
    
    private static List<Map<String, String>> buildSelectOptions(List<Account> accounts) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Account acc : accounts) {
            options.add(new Map<String, String>{
                'label' => acc.Name,
                    'value' => acc.Id
                    });
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getChildAccounts(Id parentId, String type) {
        return [
            SELECT Id, Name 
            FROM Account 
            WHERE ParentId = :parentId 
            AND Distributor_Type__c = :type
        ];
    }
    @AuraEnabled(cacheable=true)
    public static Account getAccountById(Id accountId) {
        return [SELECT Id, Name, ParentId, RecordType.Name FROM Account WHERE Id = :accountId LIMIT 1];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getSuperDistributorOptions() {
        Id recordId = recordTypeMap.get('Super Distributor');
        return [SELECT Id, Name FROM Account WHERE RecordTypeId = :recordId AND Active__c = true AND L1_Approved__c = true AND L2_Approved__c = true];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getDistributorOptions() {
        Id recordId = recordTypeMap.get('Distributor');
        return [SELECT Id, Name FROM Account WHERE RecordTypeId = :recordId AND Active__c = true AND L1_Approved__c = true AND L2_Approved__c = true];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getSubDistributorOptions() {
        Id recordId = recordTypeMap.get('Sub Distributor');
        return [SELECT Id, Name FROM Account WHERE RecordTypeId = :recordId AND Active__c = true AND L1_Approved__c = true AND L2_Approved__c = true];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Hospital__c> getHospitalOptions() {
        return [SELECT Id, Name FROM Hospital__c ORDER BY Name ASC];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Zydus_Product__c> getProductOptions() {
        return [SELECT Id, Name FROM Zydus_Product__c ORDER BY Name ASC];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Zydus_Price_Book__c> getPriceBookOptions() {
        try {
            return [SELECT Id, Price_Book_Name__c FROM Zydus_Price_Book__c WHERE IsActive__c = TRUE];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Pricebook options: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getDistributorTypePicklistValues() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Account.Distributor_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(entry.getLabel());
            }
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getZydusAccounts() {
        return [SELECT Id, Name FROM Account WHERE RecordType.Name = 'Zydus' ORDER BY Name ASC];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Position__c> getZydusSalesRepPositions() {
        return [SELECT Id, Name FROM Position__c ORDER BY Name ASC];
    }
    
    @AuraEnabled(cacheable=true)
    public static String getLatestDistributorId() {
        List<Account> accounts = [SELECT Distributor_Id__c FROM Account  WHERE Distributor_Id__c != null ORDER BY CreatedDate DESC LIMIT 1];
        return accounts.isEmpty() ? '00000' : accounts[0].Distributor_Id__c;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getLatestHospitalId() {
        List<Hospital__c> hospitals = [SELECT Hospital_ID__c FROM Hospital__c ORDER BY CreatedDate DESC LIMIT 1];
        return hospitals.isEmpty() ? '00000' : hospitals[0].Hospital_ID__c;
    }
    
    @AuraEnabled
    public static Account getCurrUserAccountDetails() {
        Id currUser = UserInfo.getUserId();
        List<Account> result = [SELECT Id, Name, RecordType.Name FROM Account WHERE Business_Owner__c = :currUser LIMIT 1];
        return result.isEmpty() ? null : result[0];
    }
}