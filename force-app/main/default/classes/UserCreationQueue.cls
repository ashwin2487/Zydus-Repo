public class UserCreationQueue implements Queueable {

    public class ContactUserWrapper {
        public Id contactId;
        public Id accountId;
        public String firstName;
        public String lastName;
        public String email;
        public String phone;

        public override String toString() {
            return 'ContactUserWrapper[contactId=' + contactId +
                ', accountId=' + accountId +
                ', firstName=' + firstName +
                ', lastName=' + lastName +
                ', phone=' + phone +
                ', email=' + email + ']';
        }
    }

    private List<ContactUserWrapper> contactUserData;

    public UserCreationQueue(List<ContactUserWrapper> contactUserData) {
        this.contactUserData = contactUserData;
    }

    public void execute(QueueableContext context) {
        List<User> usersToCreate = new List<User>();
        Map<Id, Account> accountMap = new Map<Id, Account>();
        Map<Id, Id> accountToUserMap = new Map<Id, Id>();

        Set<Id> accountIds = new Set<Id>();
        for (ContactUserWrapper data : contactUserData) {
            if (data.accountId != null) {
                accountIds.add(data.accountId);
            }
        }

        if (!accountIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, RecordType.Name
                FROM Account
                WHERE Id IN :accountIds
            ]) {
                accountMap.put(acc.Id, acc);
            }
        }

        Id superDistributorProfileId = [SELECT Id FROM Profile WHERE Name = 'SuperDistributorProfile' LIMIT 1].Id;
        Id distributorProfileId = [SELECT Id FROM Profile WHERE Name = 'DistributorProfile' LIMIT 1].Id;
        Id subDistributorProfileId = [SELECT Id FROM Profile WHERE Name = 'SubDistributorProfile' LIMIT 1].Id;

        Id superDistributorPermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'superDistributorpermissionSet' LIMIT 1].Id;
        Id distributorPermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'distributorpermissionSet' LIMIT 1].Id;
        Id subDistributorPermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'subDistributorpermissionSet' LIMIT 1].Id;
		
        Map<String, Id> recordTypeToRoleId = new Map<String, Id>();
        for (UserRole user : [SELECT Id, Name FROM UserRole]) {
            recordTypeToRoleId.put(user.Name, user.Id);
        }

        List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
		Id managerid = [select Id , name from User where username = 'ashwinhzydus@gmail.com.developer'].id;
        for (ContactUserWrapper data : contactUserData) {
            if (data.accountId == null || !accountMap.containsKey(data.accountId)) continue;

            Account acc = accountMap.get(data.accountId);
            String recordType = acc.RecordType.Name;
            Id roleId = recordTypeToRoleId.get(recordType);
            Id profileId;
            Id permissionSetId;
            
            if (recordType == 'Super Distributor') {
                profileId = superDistributorProfileId;
                permissionSetId = superDistributorPermissionSetId;
            } else if (recordType == 'Distributor') {
                profileId = distributorProfileId;
                permissionSetId = distributorPermissionSetId;
            } else if (recordType == 'Sub Distributor') {
                profileId = subDistributorProfileId;
                permissionSetId = subDistributorPermissionSetId;
            } else {
                continue;
            }

            String username = data.email;
            String alias = (data.firstName + data.lastName).length() > 8
                ? (data.firstName + data.lastName).substring(0, 8)
                : (data.firstName + data.lastName);

            User user = new User(
                FirstName = data.firstName,
                LastName = data.lastName,
                Email = data.email,
                Username = username,
                Alias = alias,
                Phone = data.phone,
                ProfileId = profileId,
                UserRoleId = roleId,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                managerid = managerid
            );

            usersToCreate.add(user);
        }

        Database.SaveResult[] results = Database.insert(usersToCreate, false);

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                User u = usersToCreate[i];
                ContactUserWrapper data = contactUserData[i];
                Account acc = accountMap.get(data.accountId);
                String recordType = acc.RecordType.Name;

                Id permissionSetId;
                if (recordType == 'Super Distributor') {
                    permissionSetId = superDistributorPermissionSetId;
                } else if (recordType == 'Distributor') {
                    permissionSetId = distributorPermissionSetId;
                } else if (recordType == 'Sub Distributor') {
                    permissionSetId = subDistributorPermissionSetId;
                } else {
                    continue;
                }

                PermissionSetAssignment psa = new PermissionSetAssignment(
                    AssigneeId = u.Id,
                    PermissionSetId = permissionSetId
                );
                psaList.add(psa);

                String tempPassword = generateRandomPassword();
                try {
                    System.setPassword(u.Id, tempPassword);
                    sendPasswordNotification(u, tempPassword);
                } catch (Exception e) {
                    System.debug('Error setting password or sending email: ' + e.getMessage());
                }

                accountToUserMap.put(data.accountId, u.Id);
            } else {
                System.debug('User insert failed: ' + results[i].getErrors()[0].getMessage());
            }
        }

        if (!psaList.isEmpty()) {
            try {
                insert psaList;
            } catch (Exception e) {
                System.debug('Error assigning permission sets: ' + e.getMessage());
            }
        }

        if (!accountToUserMap.isEmpty()) {
            System.enqueueJob(new AccountUpdateQueue(accountToUserMap));
        }
    }

    private static final String LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    private static final String DIGITS = '0123456789';
    private static final String CHAR_SET = LETTERS + DIGITS;
    private static final Integer PASSWORD_LENGTH = 12;

    public static String generateRandomPassword() {
        List<String> chars = new List<String>();

        Integer letterIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), LETTERS.length());
        chars.add(LETTERS.substring(letterIndex, letterIndex + 1));

        Integer digitIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), DIGITS.length());
        chars.add(DIGITS.substring(digitIndex, digitIndex + 1));

        for (Integer i = 2; i < PASSWORD_LENGTH; i++) {
            Integer index = Math.mod(Math.abs(Crypto.getRandomInteger()), CHAR_SET.length());
            chars.add(CHAR_SET.substring(index, index + 1));
        }

        for (Integer i = chars.size() - 1; i > 0; i--) {
            Integer j = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
            String temp = chars[i];
            chars[i] = chars[j];
            chars[j] = temp;
        }

        return String.join(chars, '');
    }

    private static void sendPasswordNotification(User newUser, String tempPassword) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(newUser.Id);
        mail.setTreatTargetObjectAsRecipient(true);
        mail.setUseSignature(false);
        mail.setSaveAsActivity(false);

        mail.setSubject('Welcome to Zydus DMS System! Your Salesforce Account Credentials');

        String emailBody = 'Dear ' + newUser.FirstName + ' ' + newUser.LastName + ',\n\n' +
            'Welcome to Zydus DMS System!\n\n' +
            'Your Salesforce account has been successfully created. Below are your login credentials:\n\n' +
            'Salesforce Login URL: https://login.salesforce.com\n\n' +
            'Email ID: ' + newUser.Email + '\n' +
            'Username: ' + newUser.Username + '\n' +
            'Temporary Password: ' + tempPassword + '\n\n' +
            'Please log in using the credentials above. You will be prompted to change your password upon first login.\n\n' +
            'If you encounter any issues, contact IT Helpdesk at helpdesk@example.com.\n\n' +
            'Best regards,\n' +
            'Zydus DMS Team';

        mail.setPlainTextBody(emailBody);

        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            if (!results[0].isSuccess()) {
                System.debug('Email send error: ' + results[0].getErrors()[0].getMessage());
            }
        } catch (Exception e) {
            System.debug('Exception during email send: ' + e.getMessage());
        }
    }
}