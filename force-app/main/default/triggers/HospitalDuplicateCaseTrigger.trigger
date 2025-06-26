trigger HospitalDuplicateCaseTrigger on Hospital__c (before insert) {
    
    System.debug('HospitalDuplicateCaseTrigger: Started processing ' + Trigger.new.size() + ' hospitals');
    
    // Get Zydus Account with more flexible query
    List<Account> zydusAccount = [
        SELECT Id, Name 
        FROM Account 
        WHERE Name = 'Zydus' 
        OR Name LIKE '%Zydus%' 
        OR Name LIKE '%ZYDUS%'
        LIMIT 1
    ];
    
    if (zydusAccount.isEmpty()) {
        System.debug('ERROR: Zydus account not found. Available accounts:');
        // Debug: Show available accounts to help identify correct name
        List<Account> allAccounts = [SELECT Id, Name FROM Account LIMIT 10];
        for (Account acc : allAccounts) {
            System.debug('Account: ' + acc.Name + ' (ID: ' + acc.Id + ')');
        }
        return;
    }
    
    System.debug('Found Zydus Account: ' + zydusAccount[0].Name + ' (ID: ' + zydusAccount[0].Id + ')');
    
    Id zydusAccountId = zydusAccount[0].Id;
    List<Case> casesToInsert = new List<Case>();
    
    for (Hospital__c hospital : Trigger.new) {
        System.debug('Processing hospital: ' + hospital.Name + ', GST: ' + hospital.GST_Number__c + ', PIN: ' + hospital.Hospital_Pin_Code__c);
        
        // Check if hospital with same GST and PIN already exists
        if (String.isNotBlank(hospital.GST_Number__c) && hospital.Hospital_Pin_Code__c != null) {
            
            // Remove the Id != condition since this is before insert (Id will be null)
            List<Hospital__c> existingHospitals = [
                SELECT Id, Name, GST_Number__c, Hospital_Pin_Code__c, Contact_Email__c, 
                       Contact_Phone__c, Address__c, City__c, State__c
                FROM Hospital__c 
                WHERE GST_Number__c = :hospital.GST_Number__c 
                AND Hospital_Pin_Code__c = :hospital.Hospital_Pin_Code__c
                LIMIT 1
            ];
            
            System.debug('Found ' + existingHospitals.size() + ' existing hospitals with GST: ' + hospital.GST_Number__c + ' and PIN: ' + hospital.Hospital_Pin_Code__c);
            
            // If duplicate found, create case and prevent hospital creation
            if (!existingHospitals.isEmpty()) {
                
                System.debug('Creating case for duplicate hospital');
                
                // Build case description
                String caseDescription = buildCaseDescription(hospital, existingHospitals[0]);
                
                // Create case for resolution
                Case duplicateCase = new Case(
                    AccountId = zydusAccountId,
                    Subject = 'Duplicate Hospital Onboarding - GST: ' + hospital.GST_Number__c + ', PIN: ' + hospital.Hospital_Pin_Code__c,
                    Description = caseDescription,
                    Status = 'New',
                    Priority = 'Medium',
                    Origin = 'System Generated'
                );
                
                // Only set Type and Reason if these fields exist on Case object
                try {
                    duplicateCase.put('Type', 'Hospital Onboarding Issue');
                    duplicateCase.put('Reason', 'Duplicate GST and PIN Code');
                } catch (Exception fieldEx) {
                    System.debug('Type/Reason fields not available on Case object: ' + fieldEx.getMessage());
                }
                
                casesToInsert.add(duplicateCase);
                
                // Add error to prevent hospital creation
                hospital.addError('Hospital already exists for the provided GST and PIN code! A case has been created for resolution. Case will be assigned to Zydus account.');
                
                System.debug('Added error to hospital record and created case');
            }
        } else {
            System.debug('Skipping hospital - missing GST or PIN: GST=' + hospital.GST_Number__c + ', PIN=' + hospital.Hospital_Pin_Code__c);
        }
    }
    
    // Insert cases if any duplicates found
    if (!casesToInsert.isEmpty()) {
        System.debug('Attempting to insert ' + casesToInsert.size() + ' cases');
        try {
            insert casesToInsert;
            System.debug('SUCCESS: Created ' + casesToInsert.size() + ' duplicate hospital cases for Zydus account.');
            
            // Log each created case
            for (Case c : casesToInsert) {
                System.debug('Created Case ID: ' + c.Id + ', Subject: ' + c.Subject);
            }
            
        } catch (Exception e) {
            System.debug('ERROR creating duplicate hospital cases: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Try to create cases individually to identify specific issues
            for (Case c : casesToInsert) {
                try {
                    insert c;
                    System.debug('Individual case created successfully: ' + c.Subject);
                } catch (Exception individualEx) {
                    System.debug('Failed to create individual case: ' + c.Subject + ', Error: ' + individualEx.getMessage());
                }
            }
        }
    } else {
        System.debug('No duplicate cases to create');
    }
    
    System.debug('HospitalDuplicateCaseTrigger: Completed processing');
    
    // Helper method to build detailed case description
    public static String buildCaseDescription(Hospital__c newHospital, Hospital__c existingHospital) {
        String description = 'DUPLICATE HOSPITAL ONBOARDING DETECTED\\n\\n';
        
        description += '--- ATTEMPTED NEW HOSPITAL ---\\n';
        description += 'Hospital Name: ' + (String.isNotBlank(newHospital.Name) ? newHospital.Name : 'Not Provided') + '\\n';
        description += 'GST Number: ' + (newHospital.GST_Number__c != null ? newHospital.GST_Number__c : 'Not Provided') + '\\n';
        description += 'PIN Code: ' + (newHospital.Hospital_Pin_Code__c != null ? String.valueOf(newHospital.Hospital_Pin_Code__c) : 'Not Provided') + '\\n';
        description += 'Contact Email: ' + (String.isNotBlank(newHospital.Contact_Email__c) ? newHospital.Contact_Email__c : 'Not Provided') + '\\n';
        description += 'Contact Phone: ' + (String.isNotBlank(newHospital.Contact_Phone__c) ? newHospital.Contact_Phone__c : 'Not Provided') + '\\n';
        description += 'Address: ' + (String.isNotBlank(newHospital.Address__c) ? newHospital.Address__c : 'Not Provided') + '\\n';
        description += 'City: ' + (String.isNotBlank(newHospital.City__c) ? newHospital.City__c : 'Not Provided') + '\\n';
        description += 'State: ' + (String.isNotBlank(newHospital.State__c) ? newHospital.State__c : 'Not Provided') + '\\n\\n';
        
        description += '--- EXISTING HOSPITAL (DUPLICATE) ---\\n';
        description += 'Hospital Name: ' + (existingHospital.Name != null ? existingHospital.Name : 'Not Available') + '\\n';
        description += 'Hospital ID: ' + existingHospital.Id + '\\n';
        description += 'GST Number: ' + (existingHospital.GST_Number__c != null ? existingHospital.GST_Number__c : 'Not Available') + '\\n';
        description += 'PIN Code: ' + (existingHospital.Hospital_Pin_Code__c != null ? String.valueOf(existingHospital.Hospital_Pin_Code__c) : 'Not Available') + '\\n';
        description += 'Contact Email: ' + (String.isNotBlank(existingHospital.Contact_Email__c) ? existingHospital.Contact_Email__c : 'Not Available') + '\\n';
        description += 'Contact Phone: ' + (String.isNotBlank(existingHospital.Contact_Phone__c) ? existingHospital.Contact_Phone__c : 'Not Available') + '\\n';
        description += 'Address: ' + (String.isNotBlank(existingHospital.Address__c) ? existingHospital.Address__c : 'Not Available') + '\\n';
        description += 'City: ' + (String.isNotBlank(existingHospital.City__c) ? existingHospital.City__c : 'Not Available') + '\\n';
        description += 'State: ' + (String.isNotBlank(existingHospital.State__c) ? existingHospital.State__c : 'Not Available') + '\\n\\n';
        
        description += '--- RESOLUTION REQUIRED ---\\n';
        description += 'Please review both hospital records and determine if:\\n';
        description += '1. This is a legitimate duplicate that should be merged\\n';
        description += '2. The GST/PIN information needs to be corrected\\n';
        description += '3. This is a new location for an existing hospital group\\n';
        description += '4. Other resolution action is required\\n\\n';
        
        description += 'Case created automatically by Hospital Onboarding system.\\n';
        description += 'Timestamp: ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss');
        
        return description;
    }
}