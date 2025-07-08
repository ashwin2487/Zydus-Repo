public without sharing class DistributorOnboardingController {

    @AuraEnabled
    public static String submitDistributorForApproval(String onboardingData) {
        
        Id currUserID=UserInfo.getUserId();
        try {
            
            String rtName=[SELECT Id, RecordType.Name FROM Account WHERE Business_Owner__c =: currUserID].RecordType.Name;
            
            
            DistributorOnboardingWrapper data =
                (DistributorOnboardingWrapper) JSON.deserialize(onboardingData, DistributorOnboardingWrapper.class);

            if (String.isBlank(data.gstNumber) || String.isBlank(data.pin)) {
                throw new AuraHandledException('GST number and PIN code are required.');
            }

            if(rtName=='Distributor' && (data.selectedDistributorType =='Super Distributor' || data.selectedDistributorType =='Distributor')  ){
                throw new AuraHandledException('You\'re not Authorized to onboard Selected Distributor Type.');
            }
            
            if(rtName =='Sub Distributor'  ){
                throw new AuraHandledException('You\'re not Authorized to onboard Distributors.');
            }
            
            String pinCode = data.pin;

            List<Account> existingAcc = [
                SELECT Id FROM Account
                WHERE GST_Number__c = :data.gstNumber AND Account_Pin_Code__c = :pinCode
            ];

            if (!existingAcc.isEmpty()) {
                return 'Distributor already exists for the provided GST and PIN code!';
            }

            Map<String, Id> recordTypeMap = new Map<String, Id>();
            for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account']) {
                recordTypeMap.put(rt.Name, rt.Id);
            }

            Id recordTypeId = recordTypeMap.get(data.selectedDistributorType);
            if (recordTypeId == null) {
                throw new AuraHandledException('Invalid distributor type: ' + data.selectedDistributorType);
            }

            Map<Id, Hospital__c> hosps = new Map<Id, Hospital__c>(
                [SELECT Id, Name FROM Hospital__c WHERE Id IN :data.selectedHospitals]
            );

            List<String> hospDetails = new List<String>();
            for (Id hospId : data.selectedHospitals) {
                Hospital__c hosp = hosps.get(hospId);
                if (hosp != null) {
                    hospDetails.add(hospId + '|' + hosp.Name); // Store both ID and Name
                }
            }

            String joinedHospDetails = hospDetails.isEmpty() ? null : String.join(hospDetails, ',');

            Account acct = new Account(
                Name                         = data.distributorName,
                Distributor_ID__c            = data.distributorId,
                Distributor_Type__c          = data.selectedDistributorType,
                Super_Distributor_Mapping__c = String.isNotEmpty(data.selectedSuperDistributor) ? data.selectedSuperDistributor : null,
                Address__c                   = data.address,
                Account_Pin_Code__c          = pinCode,
                City__c                      = data.city,
                State__c                     = data.selectedState,
                Ship_Address__c				 = data.shipAddress,
                Ship_City__c				 = data.shipCity,
                Ship_State__c				 = data.shipState,
                Ship_Pin_Code__c			 = data.shipPin,
                Contact_First_Name__c        = data.firstName,
                Contact_Last_Name__c         = data.lastName,
                Contact_Person_Email__c      = data.email,
                Mobile_Number__c             = data.mobile,
                Bank_Account_Number__c       = data.accountNumber,
                IFSC_Code__c                 = data.ifsc,
                Bank_Name__c                 = data.bankName,
                PAN_Number__c                = data.panNumber,
                GST_Number__c                = data.gstNumber,
                Zydus_Price_Book__c          = data.selectedPriceBook,
                sales_Rep_Position_Mapping__c = data.salesRep,
                Hospital_Mapping__c          = joinedHospDetails,
                Zydus_Mapping__c             = data.zydusMapping,
                Drug_Licence_Number__c       = data.drugLicenceNumber,
                Validity_of_Drug_Licence__c  = data.validTillDate,
                RecordTypeId                 = recordTypeId,
                L1_Approved__c               = false,
                L2_Approved__c               = false,
                Active__c                    = false,
                DL_Active__c                 = true,
                Credit_Limit_Start_Date__c   = data.creditStartDate,
                Credit_Limit_End_Date__c     = data.creditEndDate,
                Payment_Term__c     		 = Decimal.valueOf(data.paymentTerm)
                
            );

            if (String.isNotEmpty(data.creditLimit)) {
                try {
                    acct.Credit_Limit_Amount__c = Decimal.valueOf(data.creditLimit);
                    acct.Available_Credit_Limit__c = Decimal.valueOf(data.creditLimit);
                } catch (Exception e) {
                    throw new AuraHandledException('Invalid Credit Limit format: ' + data.creditLimit);
                }
            }

            // Set ParentId based on type
            Map<String, String> parentMap = new Map<String, String> {
                'Sub Distributor'   => data.selectedDistributor,
                'Distributor'       => data.selectedSuperDistributor,
                'Super Distributor' => data.zydusMapping
            };

            if (parentMap.containsKey(data.selectedDistributorType)) {
                String parentId = parentMap.get(data.selectedDistributorType);
                if (String.isNotEmpty(parentId)) {
                    acct.ParentId = parentId;
                }
            }

            insert acct;

            // Attach uploaded files
            if (data.uploadedFiles != null && !data.uploadedFiles.isEmpty()) {
                List<ContentVersion> cvs = new List<ContentVersion>();
                for (FileUpload f : data.uploadedFiles) {
                    if (String.isNotEmpty(f.fileName) && String.isNotEmpty(f.fileData)) {
                        cvs.add(new ContentVersion(
                            Title = f.fileName,
                            PathOnClient = f.fileName,
                            VersionData = EncodingUtil.base64Decode(f.fileData),
                            FirstPublishLocationId = acct.Id
                        ));
                    }
                }
                if (!cvs.isEmpty()) {
                    insert cvs;
                }
            }

            // Submit for approval
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(acct.Id);
            req.setProcessDefinitionNameOrId(System.Label.DIstributorOnboardingApproval);
            req.setComments('Distributor submitted for approval');
            Approval.ProcessResult res = Approval.process(req);

            // Send email notification
            User currentUser = [SELECT Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
            String subject = 'New Distributor Onboarded – Awaiting Approval (L01 & L02)';
            String body =
                'Dear ' + currentUser.Name + ',\n\n' +
                'We are pleased to inform you that you have successfully onboarded a new distributor named ' + acct.Name + '. ' +
                'The corresponding account has been created in the system.\n\n' +
                'The account has now been submitted for L01 and L02 level approvals. ' +
                'You will be notified once the approval process is completed.\n\n' +
                'Thank you for your continued efforts and support.\n\n' +
                'Best regards,\nZydus DMS Team';
            
			String notyBody='Dear ' + currentUser.Name + ',\n\n' +
                'We are pleased to inform you that you have successfully onboarded a new distributor named ' + acct.Name + '. ';
            
            NotificationService.notifyUsers(new Set<String>{currentUser.Id}, acct.Id, subject, body);
            NotificationService.sendEmail(new List<String>{currentUser.Email}, subject, body);

            return res.isSuccess()
                ? 'Account created and submitted for approval successfully!'
                : 'Failed to submit for approval: ' + (res.getErrors().isEmpty() ? 'Unknown error.' : res.getErrors()[0].getMessage());

        } catch (Exception ex) {
            throw new AuraHandledException('Error in submitting distributor: ' + ex.getMessage());
        }
    }

    public class DistributorOnboardingWrapper {
        @AuraEnabled public String distributorName;
        @AuraEnabled public String distributorId;
        @AuraEnabled public String selectedDistributorType;
        @AuraEnabled public String selectedSuperDistributor;
        @AuraEnabled public String selectedDistributor;
        @AuraEnabled public String address;
        @AuraEnabled public String shipAddress;
        @AuraEnabled public String shipPin;
        @AuraEnabled public String shipCity;
        @AuraEnabled public String shipState;
        @AuraEnabled public String city;
        @AuraEnabled public String selectedState;
        @AuraEnabled public String pin;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String ifsc;
        @AuraEnabled public String bankName;
        @AuraEnabled public String panNumber;
        @AuraEnabled public String gstNumber;
        @AuraEnabled public String selectedPriceBook;
        @AuraEnabled public String creditLimit;
        @AuraEnabled public Date creditStartDate;
        @AuraEnabled public Date creditEndDate;
        @AuraEnabled public String salesRep;
        @AuraEnabled public List<String> selectedHospitals;
        @AuraEnabled public String zydusMapping;
        @AuraEnabled public String drugLicenceNumber;
        @AuraEnabled public Date validTillDate;
        @AuraEnabled public String paymentTerm;
        @AuraEnabled public List<FileUpload> uploadedFiles;
    }

    public class FileUpload {
        @AuraEnabled public String fileName;
        @AuraEnabled public String fileData;
    }
}