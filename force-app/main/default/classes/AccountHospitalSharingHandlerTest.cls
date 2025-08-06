@isTest
public class AccountHospitalSharingHandlerTest {
    @isTest
    public static void testCreateHospitalShare() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User businessOwner = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tbown',
            Email = 'owner@example.com',
            Username = 'test.owner' + DateTime.now().getTime() + '@example.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert businessOwner;

        Account acc = new Account(
            Name = 'Test Account',
            Business_Owner__c = businessOwner.Id
        );
        insert acc;

        Hospital__c hospital = new Hospital__c(
            Name = 'Test Hospital',
            Address__c = '123 Main Road',
            PAN_Number__c = 'ABCDE1234F',
            Phyzii_Hospital_ID__c = 'PHY123',
            Ship_Title__c = 'Dr.',
            State__c = 'Gujarat',
            City__c = 'Ahmedabad',
            Shipping_Address__c = '123 Main Road',
            Ship_City__c = 'Ahmedabad',
            Ship_State__c = 'Gujarat',
            Ship_Pin__c = '380001',
            Hospital_ID__c = 'HOSP001'
        );
        insert hospital;

        Warehouse__c warehouse = new Warehouse__c(
            Name = 'Test Warehouse',
            Hospital__c = hospital.Id
        );
        insert warehouse;

        Account_Hospital__c accHosp = new Account_Hospital__c(
            Account__c = acc.Id,
            Hospital__c = hospital.Id
        );
        insert accHosp;

        Test.startTest();
        AccountHospitalSharingHandler.createHospitalShare(new List<Account_Hospital__c>{ accHosp });
        Test.stopTest();

        List<Hospital__Share> hospitalShares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM Hospital__Share
            WHERE ParentId = :hospital.Id AND UserOrGroupId = :businessOwner.Id
        ];
        System.assertEquals(1, hospitalShares.size(), 'Hospital__Share should be created');
        System.assertEquals('Edit', hospitalShares[0].AccessLevel);
        System.assertEquals(Schema.Hospital__Share.RowCause.Manual, hospitalShares[0].RowCause);

        List<Warehouse__Share> warehouseShares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM Warehouse__Share
            WHERE ParentId = :warehouse.Id AND UserOrGroupId = :businessOwner.Id
        ];
        System.assertEquals(1, warehouseShares.size(), 'Warehouse__Share should be created');
        System.assertEquals('Edit', warehouseShares[0].AccessLevel);
        System.assertEquals(Schema.Warehouse__Share.RowCause.Manual, warehouseShares[0].RowCause);
    }
}