public without sharing class HospitalOnboardingController{
    
    public class HospitalPayload {
        @AuraEnabled public String hospitalName;
        @AuraEnabled public String hospRegistrationNumber;
        @AuraEnabled public String hospGroup;
        
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String ccEmail;
        
        @AuraEnabled public String billingAddress;
        @AuraEnabled public String city;
        @AuraEnabled public String selectedState;
        @AuraEnabled public String pin;
        
        @AuraEnabled public String shippingAddress;
        @AuraEnabled public String shipCity;
        @AuraEnabled public String selectedShipState;
        @AuraEnabled public String shipPin;
        @AuraEnabled public String shipTitle;
        
        @AuraEnabled public String selectedSuperDistributor;
        @AuraEnabled public String selectedDistributor;
        @AuraEnabled public String selectedSubDistributor;
        @AuraEnabled public String selectedPriceBook;
        
        @AuraEnabled public String panNumber;
        @AuraEnabled public String gstNumber;
        @AuraEnabled public String dlNo;
        @AuraEnabled public Date dlExpiryDate;
        
        @AuraEnabled public String doctorName;
        @AuraEnabled public String paymentTerm;
        @AuraEnabled public String invoiceComment;
        
        @AuraEnabled public String hospitalId;
        @AuraEnabled public String phyziiId;
        @AuraEnabled public List<String> selectedProducts;
        @AuraEnabled public String commentOptionSelected;
    }
    
    @AuraEnabled
    public static String createHospitalRecord(String onboardingData) {
        
        HospitalPayload payload =(HospitalPayload) JSON.deserialize(onboardingData, HospitalPayload.class);
        
        List<Hospital__c> existingHosp = [
            SELECT Id, GST_Number__c, Hospital_Pin_Code__c 
            FROM Hospital__c 
            WHERE GST_Number__c = :payload.gstNumber 
            AND Hospital_Pin_Code__c = :payload.pin
        ];
        
        
        if (!existingHosp.isEmpty()) {
            try {
                List<Account> zydusAccount = [
                    SELECT Id, Name 
                    FROM Account 
                    WHERE Name = 'Zydus' 
                    OR Name LIKE '%Zydus%' 
                    OR Name LIKE '%ZYDUS%'
                    LIMIT 1
                ];
                
                if (!zydusAccount.isEmpty()) {
                    Case duplicateCase = new Case(
                        AccountId = zydusAccount[0].Id,
                        Subject = 'Duplicate Hospital Onboarding - GST: ' + payload.gstNumber + ', PIN: ' + payload.pin,
                        Status = 'New',
                        Priority = 'Medium',
                        Origin = 'Hospital Onboarding System'
                    );
                    
                    try {
                        duplicateCase.put('Type', 'Hospital Onboarding Issue');
                        duplicateCase.put('Reason', 'Duplicate GST and PIN Code');
                    } catch (Exception fieldEx) {
                        System.debug('Type/Reason fields not available on Case object: ' + fieldEx.getMessage());
                    }
                    
                    insert duplicateCase;
                    
                    System.debug('Created duplicate hospital case: ' + duplicateCase.Id + ' for Zydus account');
                    return 'Hospital already exists for the provided GST and PIN code!';
                    
                } else {
                    System.debug('Zydus account not found. Case not created.');
                    return 'Hospital already exists for the provided GST and PIN code!';
                }
                
            } catch (Exception caseEx) {
                System.debug('Error creating duplicate case: ' + caseEx.getMessage());
                return 'Hospital already exists for the provided GST and PIN code!';
            }
        } 
        
        try {  
            Hospital__c hosp = new Hospital__c(
                Name                      = payload.hospitalName,
                Contact_First_Name__c	  = payload.firstName,
                Contact_Last_Name__c	  = payload.lastName,
                Contact_Email__c		  = payload.email,
                Contact_Phone__c		  = payload.mobile,
                Registration_Number__c    = payload.hospRegistrationNumber,
                Group__c 				  = String.isBlank(payload.hospGroup) ? null : payload.hospGroup,
                Zydus_Price_Book__c		  = String.isBlank(payload.selectedPriceBook) ? null : payload.selectedPriceBook,
                CC_Email_Address__c       = payload.ccEmail,
                Address__c                = payload.billingAddress,
                City__c                   = payload.city,
                State__c                  = payload.selectedState,
                Hospital_Pin_Code__c      = payload.pin,
                Shipping_Address__c       = payload.shippingAddress,
                Ship_City__c              = payload.shipCity,
                Ship_State__c             = payload.selectedShipState,
                Ship_Pin__c               = payload.shipPin,
                Ship_Title__c             = payload.shipTitle,
                PAN_Number__c             = payload.panNumber,
                GST_Number__c             = payload.gstNumber,
                DL_no__c                  = payload.dlNo,
                DL_Expire_Date__c         = payload.dlExpiryDate,
                Doctors_Name__c           = payload.doctorName,
                Payment_Term__c           = Decimal.valueOf(payload.paymentTerm),
                Invoice_Comment__c        = payload.invoiceComment,
                Hospital_ID__c            = payload.hospitalId,
                Phyzii_Hospital_ID__c     = payload.phyziiId,
                Comment_Options__c        = payload.commentOptionSelected
            );
            insert hosp;
            
            List<Account_Hospital__c> junctions = new List<Account_Hospital__c>();
            if (String.isNotBlank(payload.selectedSuperDistributor)) {
                junctions.add(new Account_Hospital__c(Account__c = payload.selectedSuperDistributor, Hospital__c = hosp.Id));
            }
            if (String.isNotBlank(payload.selectedDistributor)) {
                junctions.add(new Account_Hospital__c(Account__c = payload.selectedDistributor, Hospital__c = hosp.Id));
            }
            if (String.isNotBlank(payload.selectedSubDistributor)) {
                junctions.add(new Account_Hospital__c(Account__c = payload.selectedSubDistributor, Hospital__c = hosp.Id));
            }
            if (!junctions.isEmpty()) insert junctions;                
            if (payload.selectedProducts != null && !payload.selectedProducts.isEmpty()) {
                List<Hospital_Product__c> HPJunctions = new List<Hospital_Product__c>();
                for (String prodId : payload.selectedProducts) {
                    System.debug('Product Id : ' + prodId);
                    HPJunctions.add(new Hospital_Product__c(Zydus_Product__c = prodId, Hospital__c = hosp.Id));
                }
                if (!HPJunctions.isEmpty()) {
                    insert HPJunctions;
                }
            }
            
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(hosp.Id);
            req.setProcessDefinitionNameOrId(System.Label.HospitalOnboardingApproval);
            req.setComments('Hospital submitted for approval');
            Approval.ProcessResult res = Approval.process(req);
            
            return res.isSuccess()
                ? 'Hospital Created and submitted for approval successfully!'
                : 'Failed to submit hospital for approval: ' + res.getErrors();
            
        } catch (Exception ex) {
            System.debug(ex.getMessage());
            throw new AuraHandledException('Error creating hospital record: ' + ex.getMessage());
        }
    }
    
}