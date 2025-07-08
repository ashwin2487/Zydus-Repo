public class AccountTriggerHandler {
    public static void preventBusinessOwnerCreditLimitChange(List<Account> newAccounts, Map<Id, Account> oldAccountMap) {
        Id currentUserId = UserInfo.getUserId();
        
        for (Account acc : newAccounts) {
            if (acc.Business_Owner__c == currentUserId && oldAccountMap.containsKey(acc.Id)) {
                Account oldAcc = oldAccountMap.get(acc.Id);
                
                // If Credit_Limit_Amount__c has changed
                if (acc.Credit_Limit_Amount__c != oldAcc.Credit_Limit_Amount__c) {
                    acc.addError('You are not authorized to change the credit limit.');
                }
            }
        }
    }
    public static void handlePrizeBookSharing(List<Account> newAccounts, Map<Id, Account> oldMap) {
        List<Zydus_Price_Book__Share> sharesToInsert = new List<Zydus_Price_Book__Share>();

        for (Account acc : newAccounts) {
            Account oldAcc = oldMap != null ? oldMap.get(acc.Id) : null;

            Boolean isInsert = oldAcc == null;
            Boolean priceBookChanged = oldAcc != null && acc.Zydus_Price_Book__c != oldAcc.Zydus_Price_Book__c;

            if (isInsert || priceBookChanged) {
                if (acc.Zydus_Price_Book__c != null && acc.Business_owner__c != null) {
                    sharesToInsert.add(new Zydus_Price_Book__Share(
                        ParentId = acc.Zydus_Price_Book__c,
                        UserOrGroupId = acc.Business_owner__c,
                        AccessLevel = 'Edit',
                        RowCause = Schema.Zydus_Price_Book__Share.RowCause.Manual
                    ));
                }
            }
        }

        if (!sharesToInsert.isEmpty()) {
            try {
                insert sharesToInsert;
            } catch (DmlException e) {
                System.debug('Error sharing Zydus_Price_Book__c: ' + e.getMessage());
            }
        }
    }
    public static void validateAccountCreation(List<Account> newAccounts) {
        User currentUser = [SELECT UserRole.Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
        String userRole = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        String userProfile = currentUser.Profile.Name;
        
        for (Account acc : newAccounts) {
            if (
                userProfile == 'System Administrator' || 
                (userRole == 'Super Distributor' && (acc.RecordType.Name == 'Distributor' || acc.RecordType.Name == 'Sub Distributor')) ||
                (userRole == 'Distributor' && acc.RecordType.Name == 'Sub Distributor')
            ) {
            } else if (acc.RecordType.Name == 'Distributor' || acc.RecordType.Name == 'Sub Distributor') {
                acc.addError('You do not have permission to create this type of Account.');
            }
        }
    }
    
    public static void createContactAndUser(List<Account> newAccounts, Map<Id, Account> oldAccountMap) {
        List<Contact> contactsToCreate = new List<Contact>();
        Map<Id, Account> accountMapForContact = new Map<Id, Account>();
        
        User currentUser = [SELECT UserRole.Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String userRole = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        String userProfile = currentUser.Profile.Name;
        
        for (Account acc : newAccounts) {
            Boolean wasInactiveBefore = oldAccountMap != null && oldAccountMap.containsKey(acc.Id)
                ? !oldAccountMap.get(acc.Id).Active__c
                : true;
            
            if (acc.Active__c && wasInactiveBefore && acc.L1_Approved__c && acc.L2_Approved__c) {
                if (
                    userProfile == 'System Administrator' || 
                    (userRole == 'Super Distributor' && (acc.RecordType.Name == 'Distributor' || acc.RecordType.Name == 'Sub Distributor')) ||
                    (userRole == 'Distributor' && acc.RecordType.Name == 'Sub Distributor')
                ) {
                    Contact con = new Contact(
                        FirstName = acc.Contact_First_Name__c,
                        LastName = acc.Contact_Last_Name__c != null ? acc.Contact_Last_Name__c : 'Default',
                        Email = acc.Contact_Person_Email__c,
                        Phone = acc.Mobile_Number__c,
                        AccountId = acc.Id
                    );
                    contactsToCreate.add(con);
                    accountMapForContact.put(acc.Id, acc);
                }
            }
        }
        Id distributorWarehouseRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Warehouse__c' AND DeveloperName = 'Distributor' LIMIT 1].Id;
        
        if (!contactsToCreate.isEmpty()) {
            insert contactsToCreate;
            
            List<Warehouse__c> warehousesToCreate = new List<Warehouse__c>();
            for (Contact con : contactsToCreate) {
                Account acc = accountMapForContact.get(con.AccountId);
                Warehouse__c wh = new Warehouse__c(
                    Name = acc.Name + ' Warehouse',
                    Account__c = acc.Id,
                    Contact__c = con.Id,
                    Address__c = acc.Ship_Address__c,
                    City__c = acc.Ship_City__c	,
                    State__c = acc.Ship_State__c,
                    Country__c = 'India',
                    ZipCode__c =String.valueOf(acc.Ship_Pin_Code__c),
                    RecordTypeId = distributorWarehouseRecordTypeId
                );
                warehousesToCreate.add(wh);
            }
            
            insert warehousesToCreate;
            
            Set<Id> accountIds = accountMapForContact.keySet();
            Map<Id, Account> accountsWithPricebooks = new Map<Id, Account>(
                [SELECT Id, Name, Zydus_Price_Book__c FROM Account WHERE Id IN :accountIds]
            );
            
            Set<Id> pricebookIds = new Set<Id>();
            for (Account acc : accountsWithPricebooks.values()) {
                if (acc.Zydus_Price_Book__c != null) {
                    pricebookIds.add(acc.Zydus_Price_Book__c);
                }
            }
            
            Map<Id, List<Zydus_Price_Book_Entry__c>> pricebookEntriesMap = new Map<Id, List<Zydus_Price_Book_Entry__c>>();
            for (Zydus_Price_Book_Entry__c pbe : [
                SELECT Id, Zydus_Product__c, Zydus_Price_Book__c, List_Price__c
                FROM Zydus_Price_Book_Entry__c
                WHERE Zydus_Product__c IN :pricebookIds AND Is_Active__c = true
            ]) {
                if (!pricebookEntriesMap.containsKey(pbe.Zydus_Price_Book__c)) {
                    pricebookEntriesMap.put(pbe.Zydus_Price_Book__c, new List<Zydus_Price_Book_Entry__c>());
                }
                pricebookEntriesMap.get(pbe.Zydus_Price_Book__c).add(pbe);
            }
            
            List<Warehouse_Product__c> warehouseProductsToInsert = new List<Warehouse_Product__c>();
            for (Warehouse__c wh : warehousesToCreate) {
                Account acc = accountsWithPricebooks.get(wh.Account__c);
                if (acc != null && acc.Zydus_Price_Book__c != null) {
                    List<Zydus_Price_Book_Entry__c> entries = pricebookEntriesMap.get(acc.Zydus_Price_Book__c);
                    if (entries != null) {
                        for (Zydus_Price_Book_Entry__c entry : entries) {
                            warehouseProductsToInsert.add(new Warehouse_Product__c(
                                Warehouse__c = wh.Id,
                                Zydus_Product__c = entry.Zydus_Product__c
                            ));
                        }
                    }
                }
            }
            
            if (!warehouseProductsToInsert.isEmpty()) {
                insert warehouseProductsToInsert;
            }
            
            List<UserCreationQueue.ContactUserWrapper> userData = new List<UserCreationQueue.ContactUserWrapper>();
            for (Contact con : contactsToCreate) {
                Account acc = accountMapForContact.get(con.AccountId);
                UserCreationQueue.ContactUserWrapper wrapper = new UserCreationQueue.ContactUserWrapper();
                wrapper.accountId = acc.Id;
                wrapper.contactId = con.Id;
                wrapper.firstName = con.FirstName;
                wrapper.lastName = con.LastName;
                wrapper.email = con.Email;
                wrapper.phone = con.Phone;
                userData.add(wrapper);
            }
            
            System.enqueueJob(new UserCreationQueue(userData));
        }
    }
    
    public static void createContract(List<Account> newAccounts, Map<Id, Account> oldAccountMap) {
        List<Contract> contractsToInsert = new List<Contract>();
        
        User currentUser = [SELECT UserRole.Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String userRole = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        String userProfile = currentUser.Profile.Name;
        
        for (Account acc : newAccounts) {
            Boolean wasInactiveBefore = oldAccountMap != null && oldAccountMap.containsKey(acc.Id)
                ? !oldAccountMap.get(acc.Id).Active__c
                : true;
            
            if (acc.Active__c && wasInactiveBefore &&
                acc.L1_Approved__c && acc.L2_Approved__c &&
                acc.ParentId != null &&
                acc.Credit_Limit_Start_Date__c != null &&
                acc.Credit_Limit_End_Date__c != null) {
                    
                    if (
                        userProfile == 'System Administrator' || 
                        userRole == 'Super Distributor' || 
                        userRole == 'Distributor'
                    ) {
                        if (acc.Credit_Limit_Start_Date__c <= acc.Credit_Limit_End_Date__c) {
                            Integer tenure = acc.Credit_Limit_Start_Date__c.daysBetween(acc.Credit_Limit_End_Date__c);
                            
                            Contract newContract = new Contract();
                            newContract.AccountId = acc.Id;
                            newContract.Contracted_Account__c = acc.ParentId;
                            newContract.StartDate = System.today();
                            newContract.Status = 'Draft';
                            newContract.ContractTerm = tenure;
                            newContract.Name = acc.Id + ' Contract with ' + acc.ParentId;
                            
                            contractsToInsert.add(newContract);
                        }
                    } else {
                        acc.addError('Only Super Distributors, Distributors, or System Administrators can create contracts.');
                    }
                }
        }
        
        if (!contractsToInsert.isEmpty()) {
            try {
                insert contractsToInsert;
                for (Contract con : contractsToInsert) {
                    con.Status = 'Activated';
                }
                update contractsToInsert;
            } catch (Exception e) {
                System.debug('Error processing contracts: ' + e.getMessage());
            }
        }
    }
}