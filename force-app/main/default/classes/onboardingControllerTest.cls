@IsTest
public class onboardingControllerTest {

    static User createTestUser(String alias, String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        User u = new User(
            FirstName = 'Test', LastName = 'User',
            Alias = alias,
            Email = alias + '@test.com',
            Username = alias + DateTime.now().getTime() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    static Hospital__c createTestHospital() {
        Hospital__c h = new Hospital__c(
            Name = 'Hospital A',
            Address__c = '123 Main St',
            PAN_Number__c = 'ABCDE1234F',
            Phyzii_Hospital_ID__c = 'PHY001',
            Ship_Title__c = 'Dr.',
            State__c = 'Gujarat',
            City__c = 'Ahmedabad',
            Shipping_Address__c = '123 Main St',
            Ship_City__c = 'Ahmedabad',
            Ship_State__c = 'Gujarat',
            Ship_Pin__c = '380001',
            Hospital_ID__c = 'HOSP001'
        );
        insert h;
        return h;
    }

    @IsTest
    static void test_fetchUserDistributorHierarchy_Admin() {
        User adminUser = createTestUser('admin', 'System Administrator');
        System.runAs(adminUser) {
            Map<String, Object> result = onboardingController.fetchUserDistributorHierarchy(adminUser.Id);
            System.assertEquals('System Admin', result.get('role'));
        }
    }

    @IsTest
    static void test_fetchUserDistributorHierarchy_NonAdmin() {
        User stdUser = createTestUser('stdusr', 'Standard User');

        Account acc = new Account(
            Name = 'SuperDist',
            Distributor_Type__c = 'Super Distributor',
            Business_Owner__c = stdUser.Id,
            Active__c = true,
            L1_Approved__c = true,
            L2_Approved__c = true
        );
        insert acc;

        System.runAs(stdUser) {
            Map<String, Object> result = onboardingController.fetchUserDistributorHierarchy(stdUser.Id);
            System.assertEquals('Super Distributor', result.get('role'));
        }
    }

    @IsTest
    static void test_getDistributorsAndSubDistributors() {
        Account superAcc = new Account(Name = 'Super A', Distributor_Type__c = 'Super Distributor');
        insert superAcc;

        Account dist = new Account(Name = 'Dist A', Distributor_Type__c = 'Distributor', ParentId = superAcc.Id);
        insert dist;

        Account subDist = new Account(Name = 'SubDist A', Distributor_Type__c = 'Sub Distributor', ParentId = dist.Id);
        insert subDist;

        onboardingController.getDistributorsBySuper(superAcc.Id);
        onboardingController.getSubDistributorsByDistributor(dist.Id);
    }

    @IsTest
    static void test_getAccountById_and_getChildAccounts() {
        Account superAcc = new Account(Name = 'Super Dist', Distributor_Type__c = 'Super Distributor');
        insert superAcc;

        Account dist = new Account(Name = 'Dist', Distributor_Type__c = 'Distributor', ParentId = superAcc.Id);
        insert dist;

        Account fetched = onboardingController.getAccountById(dist.Id);
        System.assertEquals(dist.Id, fetched.Id);

        List<Account> children = onboardingController.getChildAccounts(superAcc.Id, 'Distributor');
        System.assertEquals(1, children.size());
    }

    @IsTest
    static void testGetHospitalOptions() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User user = new User(
            FirstName = 'Test', LastName = 'User',
            Email = 'tu@example.com',
            Username = 'tu' + DateTime.now().getTime() + '@example.com',
            Alias = 'tusr',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert user;
    
        Account acc = new Account(Name = 'Account', Business_Owner__c = user.Id);
        insert acc;
    
        // Create Hospital with all required fields
        Hospital__c hospital = new Hospital__c(
            Name = 'Test Hospital',
            Address__c = '123 Street',
            PAN_Number__c = 'ABCDE1234F',
            Phyzii_Hospital_ID__c = 'PHY123',
            Ship_Title__c = 'Dr.',
            State__c = 'Gujarat',
            City__c = 'Ahmedabad',
            Shipping_Address__c = '123 Street',
            Ship_City__c = 'Ahmedabad',
            Ship_State__c = 'Gujarat',
            Ship_Pin__c = '380001',
            Hospital_ID__c = 'HOSP001'
        );
        insert hospital;
    
        // ✅ Create Warehouse record tied to the hospital — this prevents the error
        Warehouse__c warehouse = new Warehouse__c(
            Name = 'Warehouse A',
            Hospital__c = hospital.Id
        );
        insert warehouse;
    
        // Create the junction object
        Account_Hospital__c accHosp = new Account_Hospital__c(
            Account__c = acc.Id,
            Hospital__c = hospital.Id
        );
        insert accHosp;
    
        System.runAs(user) {
            List<Hospital__c> result = onboardingController.getHospitalOptions();
            System.assert(!result.isEmpty());
        }
    }

    @IsTest
    static void test_getLatestDistributorAndHospitalId() {
        Account acc = new Account(Name = 'Acc', Distributor_Id__c = 'D1001');
        insert acc;

        Hospital__c hosp = createTestHospital();

        String distId = onboardingController.getLatestDistributorId();
        String hospId = onboardingController.getLatestHospitalId();

        System.assertEquals('D1001', distId);
        System.assertEquals('HOSP001', hospId);
    }

    @IsTest
    static void test_getPicklistAndZydusMethods() {
        onboardingController.getDistributorTypePicklistValues();
        onboardingController.getZydusAccounts();
        onboardingController.getZydusSalesRepPositions();
    }

    @IsTest
    static void test_getCurrUserAccountDetails() {
        User user = createTestUser('currusr', 'Standard User');

        Account acc = new Account(Name = 'Curr Acc', Business_Owner__c = user.Id);
        insert acc;

        System.runAs(user) {
            Account result = onboardingController.getCurrUserAccountDetails();
            System.assertNotEquals(null, result);
        }
    }
}