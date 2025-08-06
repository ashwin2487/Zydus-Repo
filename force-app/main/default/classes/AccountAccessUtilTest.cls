@isTest
public class AccountAccessUtilTest {

    @isTest
    static void testGetParentBusinessOwner_ValidId() {
        // Create test user to assign as business owner
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Email = 'owner@example.com',
            Username = 'test.owner' + DateTime.now().getTime() + '@example.com',
            Alias = 'towner',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Create test Account
        Account parentAcc = new Account(
            Name = 'Parent Account',
            State__c = 'Gujarat',
            Business_Owner__c = testUser.Id,
            zydus_mapping__c = 'Mapping123'
        );
        insert parentAcc;

        Test.startTest();
        Account result = AccountAccessUtil.getParentBusinessOwner(parentAcc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected non-null Account');
        System.assertEquals(testUser.Id, result.Business_Owner__c, 'Business Owner mismatch');
        System.assertEquals('Gujarat', result.State__c);
    }

    @isTest
    static void testGetParentBusinessOwner_InvalidId() {
        Id fakeId = '001000000000000AAA'; // Random/fake ID

        Test.startTest();
        Account result = AccountAccessUtil.getParentBusinessOwner(fakeId);
        Test.stopTest();

        System.assertEquals(null, result, 'Expected null for non-existent Account');
    }
}