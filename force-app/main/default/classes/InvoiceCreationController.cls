public without sharing class InvoiceCreationController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserAccountsAndHospitals() {
        Id userId = UserInfo.getUserId();
        
        List<Account> primaryAccounts = [
            SELECT Id, Name, Validity_of_Drug_Licence__c, PAN_Number__c, Mobile_Number__c,Contact_Person_Email__c,
            Address__c, City__c,State__c, Account_Pin_Code__c
            FROM Account 
            WHERE Business_Owner__c = :userId
        ];
        
        Set<Id> accountIds = new Set<Id>();
        Map<Id, Account> allAccountsMap = new Map<Id, Account>();
        
        for (Account acc : primaryAccounts) {
            accountIds.add(acc.Id);
            allAccountsMap.put(acc.Id, acc);
        }
        
        // Get child accounts
        List<Account> childAccounts = [
            SELECT Id, Name, ParentId, Validity_of_Drug_Licence__c, PAN_Number__c, Mobile_Number__c,Contact_Person_Email__c,
            Address__c, City__c,State__c, Account_Pin_Code__c
            FROM Account 
            WHERE ParentId IN :accountIds
        ];
        
        for (Account child : childAccounts) {
            accountIds.add(child.Id);
            allAccountsMap.put(child.Id, child);
        }
        
        Map<Id, String> hospitalMap = new Map<Id, String>();
        
        Id currUserId = UserInfo.getUserId();
        Account currentAccount = [
            SELECT Id, RecordType.DeveloperName
            FROM Account
            WHERE Business_Owner__c = :currUserId
            LIMIT 1
        ];
        
        String rtName = currentAccount.RecordType.DeveloperName;
        Set<Id> relatedAccountIds = new Set<Id>();
        relatedAccountIds.add(currentAccount.Id); 
        
        if (rtName == 'Super_Distributor') {
            List<Account> distributors = [
                SELECT Id FROM Account WHERE ParentId = :currentAccount.Id
            ];
            for (Account dist : distributors) {
                relatedAccountIds.add(dist.Id);
            }
            if (!distributors.isEmpty()) {
                List<Account> subDistributors = [
                    SELECT Id FROM Account WHERE ParentId IN :distributors
                ];
                for (Account subDist : subDistributors) {
                    relatedAccountIds.add(subDist.Id);
                }
            }
        }else if (rtName == 'Distributor') {
            List<Account> subDistributors = [
                SELECT Id FROM Account WHERE ParentId = :currentAccount.Id
            ];
            for (Account subDist : subDistributors) {
                relatedAccountIds.add(subDist.Id);
            }
        }
        
        if (!relatedAccountIds.isEmpty()) {
            
            List<Account_Hospital__c> accHospList = [
                SELECT Hospital__c, Hospital__r.Name
                FROM Account_Hospital__c
                WHERE Account__c IN :relatedAccountIds
                AND Hospital__c != null
                AND Hospital__r.Name != null
            ];
            
            for (Account_Hospital__c ah : accHospList) {
                if (!hospitalMap.containsKey(ah.Hospital__c)) {
                    hospitalMap.put(ah.Hospital__c, ah.Hospital__r.Name);
                }
            }
        }
        
        
        List<String> invoiceTypePicklist = new List<String>();
        Schema.DescribeFieldResult fieldResult = Invoice__c.Invoice_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            invoiceTypePicklist.add(entry.getLabel());
        }
        
        return new Map<String, Object>{
            'accounts' => allAccountsMap.values(),
                'hospitals' => hospitalMap,
                'invoiceTypes' => invoiceTypePicklist
                };
                    }
    
    @AuraEnabled
    public static Map<String, Object> RelatedDCToHosp(Id HospId) {
        ID userId = UserInfo.getUserId();
        
        // Get account related to current user
        ID relatedAccountId = [SELECT Id FROM Account WHERE Business_Owner__c = :userId LIMIT 1].Id;
        
        Map<Id, String> DCMap = new Map<Id, String>();
        
        // Fetch Delivery Challans
        List<Delivery_Challan__c> DCs = [
            SELECT Id, Consignee_Hospital__c, Name, Total_Quantity__c, 
            Consignor_Distributor__c, Invoiced_To_Hospital_Quantity__c, 
            Invoiced_By_Parent_Account_Quantity__c 
            FROM Delivery_Challan__c 
            WHERE Consignee_Hospital__c = :HospId 
            AND RecordType.Name = 'HDC'
            AND Consignor_Distributor__c = :relatedAccountId
        ];
        
        // Filter and build map
        for (Delivery_Challan__c dc : DCs) {
            if (dc.Invoiced_To_Hospital_Quantity__c < dc.Total_Quantity__c) {
                DCMap.put(dc.Id, dc.Name);
            }
        }
        
        return new Map<String, Object>{
            'relatedDCs' => DCMap
                };
                    }
    
    public class WarehouseProductLineItemWrapper {
        @AuraEnabled public Warehouse_Product_Line_Items__c record;
        @AuraEnabled public Decimal netAmount;
        @AuraEnabled public Decimal cgst;
        @AuraEnabled public Decimal sgst;
        @AuraEnabled public Decimal igst;
        
        public WarehouseProductLineItemWrapper(
            Warehouse_Product_Line_Items__c rec,
            Decimal netAmount,
            Decimal cgst,
            Decimal sgst,
            Decimal igst
        ) {
            this.record = rec;
            this.netAmount = netAmount;
            this.cgst = cgst;
            this.sgst = sgst;
            this.igst = igst;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<WarehouseProductLineItemWrapper> getWarehouseProductLineItems(
        Id hospitalId,
        Id deliveryChallanId
    ) {
        if (hospitalId == null || deliveryChallanId == null) {
            return new List<WarehouseProductLineItemWrapper>();
        }
        
        Delivery_Challan__c dc = [SELECT Id, Consignor_Distributor__c FROM Delivery_Challan__c WHERE Id=:deliveryChallanId];
        
        // Step 1: Get all warehouses for the hospital
        List<Warehouse__c> whList = [
            SELECT Id, Account__c
            FROM Warehouse__c
            WHERE Hospital__c = :hospitalId
        ];
        if (whList.isEmpty()) {
            return new List<WarehouseProductLineItemWrapper>();
        }
        Set<Id> warehouseIds = new Set<Id>();
        for (Warehouse__c w : whList) warehouseIds.add(w.Id);
        
        // Step 2: Get Challan Line Items
        List<Delivery_Challan_Line_Item__c> challanItems = [
            SELECT Id
            FROM Delivery_Challan_Line_Item__c
            WHERE Delivery_Challan__c = :deliveryChallanId
        ];
        if (challanItems.isEmpty()) return new List<WarehouseProductLineItemWrapper>();
        Set<Id> dcLineIds = new Set<Id>();
        for (Delivery_Challan_Line_Item__c dcli : challanItems) dcLineIds.add(dcli.Id);
        
        // Step 3: Get Warehouse Product Line Items (including unit price)
        List<Warehouse_Product_Line_Items__c> wpList = [
            SELECT Id,
            Serial_Number__c,
            Condition__c,
            Sold_Date__c,
            Supplied_Date__c,
            Status__c,
            Warehouse__c,
            Unit_Price__c,
            Connected_Warehouse__c,
            Warehouse__r.Zydus_Product__r.Name,
            Warehouse__r.Zydus_Product__r.HSN_Code__c,
            Delivery_Challan_Line_Item__c,
            Delivery_Challan_Line_Item__r.Delivery_Challan__r.Consignee_Hospital__r.Zydus_Price_Book__c,
            Delivery_Challan_Line_Item__r.Delivery_Challan__r.Consignor_Distributor__r.Zydus_Price_Book__c,
            GRN__r.Delivery_Challan__r.Name,
            Delivery_Challan_Line_Item__r.Zydus_Price_Book_Entry__r.Bill_Discount_Amount__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Delivery_Challan_Line_Item__c IN :dcLineIds
            AND Connected_Warehouse__c IN :warehouseIds
        ];
        if (wpList.isEmpty()) return new List<WarehouseProductLineItemWrapper>();
        
        String buyerState = [SELECT State__c FROM Hospital__c WHERE Id = :hospitalId].State__c;
        String supplierState = [SELECT State__c FROM Account WHERE Id = :dc.Consignor_Distributor__c].State__c;
        String supplyType = buyerState == supplierState ? 'Intra-State' : 'Inter-State';
        
        // Collect HSN codes
        Set<Id> hsnCodeIds = new Set<Id>();
        for (Warehouse_Product_Line_Items__c wp : wpList) {
            if (wp.Warehouse__r.Zydus_Product__r.HSN_Code__c != null) {
                hsnCodeIds.add(wp.Warehouse__r.Zydus_Product__r.HSN_Code__c);
            }
        }
        
        // Fetch tax rates
        Date today = Date.today();
        Map<String, HSN_Tax_Master_Link__c> taxRateMap = new Map<String, HSN_Tax_Master_Link__c>();
        for (HSN_Tax_Master_Link__c tax : [
            SELECT HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c, Tax_Master__r.State__c
            FROM HSN_Tax_Master_Link__c
            WHERE HSN_Code__c IN :hsnCodeIds
            AND Is_Active__c = TRUE
            AND Tax_Master__r.Is_Active__c = TRUE
            AND Tax_Master__r.Effective_From__c <= :today
            AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :today)
        ]) {
            String key = tax.HSN_Code__c + '_' + supplierState + '_' + tax.Supply_Type__c;
            taxRateMap.put(key, tax);
        }
        
        // Build wrapper list
        List<WarehouseProductLineItemWrapper> result = new List<WarehouseProductLineItemWrapper>();
        for (Warehouse_Product_Line_Items__c wp : wpList) {
            Decimal unitPrice = wp.Unit_Price__c != null ? wp.Unit_Price__c : 0;
            Decimal cgst = 0, sgst = 0, igst = 0;
            Id hsnId = wp.Warehouse__r.Zydus_Product__r.HSN_Code__c;
            String key = hsnId + '_' + supplierState + '_' + supplyType;
            HSN_Tax_Master_Link__c tax = taxRateMap.get(key);
            if (tax != null) {
                if (supplyType == 'Intra-State') {
                    cgst = unitPrice * (tax.CGST__c / 100);
                    sgst = unitPrice * (tax.SGST__c / 100);
                } else {
                    igst = unitPrice * (tax.IGST__c / 100);
                }
            }
            result.add(new WarehouseProductLineItemWrapper(wp, unitPrice + cgst + sgst + igst, cgst, sgst, igst));
        }
        return result;
    }
    
    
    @AuraEnabled
    public static Id saveInvoice(String invoiceData) {
        try {
            Map<String, Id> recordTypeMap = new Map<String, Id>();
            for (RecordType rt : [
                SELECT Id, Name FROM RecordType WHERE SObjectType = 'Invoice__c'
            ]) {
                recordTypeMap.put(rt.Name, rt.Id);
            }
            
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(invoiceData);
            Map<String, Object> patient = (Map<String, Object>) data.get('patient');
            Map<String, Object> doctor = (Map<String, Object>) data.get('doctor');
            List<Object> rawIds = (List<Object>) data.get('lineItemIds');
            List<Id> lineItemIds = new List<Id>();
            Map<Id, Map<String, Object>> inputLineItemMap = new Map<Id, Map<String, Object>>();
            
            for (Object obj : rawIds) {
                if (obj instanceof Map<String, Object>) {
                    Map<String, Object> mapObj = (Map<String, Object>) obj;
                    if (mapObj.containsKey('id') && mapObj.get('id') != null) {
                        Id lid = (Id) mapObj.get('id');
                        lineItemIds.add(lid);
                        inputLineItemMap.put(lid, mapObj);
                    }
                } else if (obj instanceof String) {
                    Id lid = (Id) obj;
                    lineItemIds.add(lid);
                }
            }
            
            Boolean hasExpiryScheme = false;
            for (Map<String, Object> inputs : inputLineItemMap.values()) {
                if (inputs != null && inputs.containsKey('scheme')) {
                    String scheme = (String) inputs.get('scheme');
                    if (scheme != null && scheme.equalsIgnoreCase('Expiry')) {
                        hasExpiryScheme = true;
                        break;
                    }
                }
            }
            
            Invoice__c invoice = new Invoice__c();
            invoice.Patient_First_Name__c = (String) patient.get('firstName');
            invoice.Patient_Last_Name__c = (String) patient.get('lastName');
            invoice.Patient_Age__c = Integer.valueOf(patient.get('age'));
            invoice.Patient_Gender__c = (String) patient.get('gender');
            invoice.Patient_Register_Number__c = (String) patient.get('patientRegisterNumber');
            invoice.Hospital__c = (String) data.get('hospitalId');
            invoice.RecordTypeId = recordTypeMap.get('Hospital Invoice');
            invoice.Invoice_Type__c = (String) data.get('invoiceType');
            String deliveryChallanList = (String) data.get('deliveryChallanId');
            if (String.isNotBlank(deliveryChallanList)) {
                invoice.Delivery_Challan__c = deliveryChallanList;
            }
            
            invoice.Consignor_Dealer__c = (String) data.get('accountId');
            invoice.Doctor_Name__c = (String) doctor.get('name');
            invoice.IP_Number__c = (String) doctor.get('ipNumber');
            invoice.Comment_Remark__c = (String) doctor.get('comment');
            invoice.CATH_Number__c = (String) doctor.get('cathNumber');
            String implantDateStr = (String) doctor.get('implantDate');
            if (!String.isBlank(implantDateStr)) {
                invoice.Date_of_Implant__c = Date.valueOf(implantDateStr);
            }
            
            invoice.Payment_Status__c = hasExpiryScheme ? 'Draft Invoice' : 'Invoice Created';
            invoice.InvoiceDate__c = Date.today();
            
            Hospital__c curHospital = [select Id ,Comment_Options__c,Invoice_Comment__c from Hospital__c where Id =: (String) data.get('hospitalId') ];
            
            if(curHospital.Comment_Options__c != null && curHospital.Comment_Options__c.contains('INL')){
                if(curHospital.Invoice_Comment__c != null){
                    invoice.Comment__c = curHospital.Invoice_Comment__c;
                }
            }
            insert invoice;
            
            List<Warehouse_Product_Line_Items__c> selectedLineItems = [
                SELECT Id, Warehouse__r.Zydus_Product__c ,Warehouse__r.Zydus_Product__r.HSN_Code__r.Name, Delivery_Challan_Line_Item__c,
                Serial_Number__c, Batch_Number__c, Unit_Price__c, Manufactured_Date__c, Expiry_Date__c
                FROM Warehouse_Product_Line_Items__c
                WHERE Id IN :lineItemIds
            ];
            
            
            List<Warehouse_Product_Line_Items__c> toUpdateWPL = new List<Warehouse_Product_Line_Items__c>();
            List<Invoice_Product_Line_Item__c> junctionRecords = new List<Invoice_Product_Line_Item__c>();
            List<Delivery_Challan_Line_Item__c> dcLineItemsToUpdate = new List<Delivery_Challan_Line_Item__c>();
            Set<String> consumedSerialNumbers = new Set<String>();
            
            for (Warehouse_Product_Line_Items__c item : selectedLineItems) {
                item.Status__c = 'Consumed';
                item.Sold_Date__c = Date.today();
                if (item.Serial_Number__c != null) consumedSerialNumbers.add(item.Serial_Number__c);
                if (item.Delivery_Challan_Line_Item__c != null) {
                    dcLineItemsToUpdate.add(new Delivery_Challan_Line_Item__c(
                        Id = item.Delivery_Challan_Line_Item__c,
                        Is_Invoiced_To_Hospital__c = true,
                        Is_Invoiced_By_parent_Account__c = true
                    ));
                }
                toUpdateWPL.add(item);
                
                Map<String, Object> inputs = inputLineItemMap.get(item.Id);
                
                Decimal cgst      = inputs.containsKey('CGST')      ? (Decimal) inputs.get('CGST')      : 0;
                Decimal sgst      = inputs.containsKey('SGST')      ? (Decimal) inputs.get('SGST')      : 0;
                Decimal igst      = inputs.containsKey('IGST')      ? (Decimal) inputs.get('IGST')      : 0;
                Decimal netAmount = inputs.containsKey('netAmount') ? (Decimal) inputs.get('netAmount') : 0;
                String scheme	  = inputs.containsKey('scheme') 	? (String) inputs.get('scheme')		: null;
                Decimal billDiscountAmount = inputs.containsKey('billDiscountAmount') ? (Decimal) inputs.get('billDiscountAmount') : 0;
                
                junctionRecords.add(new Invoice_Product_Line_Item__c(
                    Invoice__c = invoice.Id,
                    Zydus_Product__c = item.Warehouse__r.Zydus_Product__c,
                    HSN__c = item.Warehouse__r.Zydus_Product__r.HSN_Code__r.Name,
                    Warehouse_Product_Line_Item__c = item.Id,
                    Serial_Number__c = item.Serial_Number__c,
                    Batch_Number__c	= item.Batch_Number__c,
                    CGST__c = cgst,
                    SGST__c = sgst,
                    IGST__c = igst,
                    Bill_Discount_Amount__c	 = billDiscountAmount,
                    Net_Amount__c = netAmount,
                    Unit_Price__c = item.Unit_Price__c,
                    Scheme__c = scheme,
                    Expiry_Date__c=item.Expiry_Date__c,
                    Manufacture_Date__c = item.Manufactured_Date__c
                    
                ));
            }
            
            if (!toUpdateWPL.isEmpty()) update toUpdateWPL;
            if (!dcLineItemsToUpdate.isEmpty()) update dcLineItemsToUpdate;
            if (!junctionRecords.isEmpty()) insert junctionRecords;
            
            if (data.containsKey('uploadedFileIds')) {
                List<Object> fileIdsRaw = (List<Object>) data.get('uploadedFileIds');
                List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
                for (Object obj : fileIdsRaw) {
                    Id contentDocumentId;
                    if (obj instanceof Map<String, Object>) {
                        Map<String, Object> fileMap = (Map<String, Object>) obj;
                        contentDocumentId = (Id) fileMap.get('documentId');
                    } else if (obj instanceof String) {
                        contentDocumentId = (Id) obj;
                    }
                    if (contentDocumentId != null) {
                        cdls.add(new ContentDocumentLink(
                            ContentDocumentId = contentDocumentId,
                            LinkedEntityId = invoice.Id,
                            ShareType = 'V',
                            Visibility = 'AllUsers'
                        ));
                    }
                }
                if (!cdls.isEmpty()) insert cdls;
            }
            
            if (invoice.Payment_Status__c == 'Draft Invoice') {
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(invoice.Id);
                req.setProcessDefinitionNameOrId('Invoice_Approval_Process');
                req.setComments('Invoice submitted for approval');
                Approval.ProcessResult res = Approval.process(req);
            }
            
            Id currentUserId = UserInfo.getUserId();
            Set<String> toBeUpdatedOwnedDeliveryChallan = new Set<String>();
            
            Set<Id> accountIds = new Set<Id>();
            for (Account acc : [
                SELECT Id
                FROM Account
                WHERE Business_Owner__c = :currentUserId
            ]) {
                accountIds.add(acc.Id);
            }
            
            if (!accountIds.isEmpty()) {
                Set<Id> warehouseIds = new Set<Id>();
                for (Warehouse__c wh : [
                    SELECT Id
                    FROM Warehouse__c
                    WHERE Account__c IN :accountIds
                ]) {
                    warehouseIds.add(wh.Id);
                }
                
                if (!warehouseIds.isEmpty() && !consumedSerialNumbers.isEmpty()) {
                    List<Warehouse_Product_Line_Items__c> ownedWarehouseLineItems = [
                        SELECT Id, Status__c, Sold_Date__c, Serial_Number__c , Delivery_Challan_Line_Item__c
                        FROM Warehouse_Product_Line_Items__c
                        WHERE Connected_Warehouse__c IN :warehouseIds
                        AND Serial_Number__c IN : consumedSerialNumbers
                    ];
                    
                    for (Warehouse_Product_Line_Items__c item : ownedWarehouseLineItems) {
                        item.Status__c = 'Consumed';
                        item.Sold_Date__c = System.today();
                        toBeUpdatedOwnedDeliveryChallan.add(item.Delivery_Challan_Line_Item__c);
                    }
                    
                    if (!ownedWarehouseLineItems.isEmpty()) {
                        update ownedWarehouseLineItems;
                    }
                }
            } 
            List<Delivery_Challan_Line_Item__c> updateToConsumedInRcvdDC = new List<Delivery_Challan_Line_Item__c>();
            If(!toBeUpdatedOwnedDeliveryChallan.isEmpty()){
                for(Delivery_Challan_Line_Item__c curItem : [select Id , Is_Invoiced_By_parent_Account__c , Is_Invoiced_To_Hospital__c 
                                                             from Delivery_Challan_Line_Item__c where Id IN :toBeUpdatedOwnedDeliveryChallan ]){
                                                                 curItem.Is_Invoiced_To_Hospital__c = true;      
                                                                 updateToConsumedInRcvdDC.add(curItem);
                                                             }
            }
            if(!updateToConsumedInRcvdDC.isEmpty()){
                update updateToConsumedInRcvdDC;
            }
            
            Set<Id> userIds = new Set<Id>();      
            List<String> emailAddresses = new List<String>();
            
            // Step 1: Get current account owned by user
            Account currentAccount = [
                SELECT Id, Business_Owner__c, Business_Owner__r.Email, ParentId 
                FROM Account 
                WHERE Business_Owner__c = :currentUserId 
                LIMIT 1
            ];
            
            // Add current account's business owner
            if (currentAccount != null && currentAccount.Business_Owner__c != null) {
                userIds.add(currentAccount.Business_Owner__c);
                if (currentAccount.Business_Owner__r.Email != null) {
                    emailAddresses.add(currentAccount.Business_Owner__r.Email);
                }
            }
            
            // Step 2: If parent account exists, fetch it via utility class
            if (currentAccount.ParentId != null) {
                Account parentAccount = AccountAccessUtil.getParentBusinessOwner(currentAccount.ParentId);
                
                if (parentAccount != null && parentAccount.Business_Owner__c != null) {
                    userIds.add(parentAccount.Business_Owner__c);
                    if (parentAccount.Business_Owner__r.Email != null) {
                        emailAddresses.add(parentAccount.Business_Owner__r.Email);
                    }
                }
            }
            
            // Step 3: Add hospital contact/CC emails
            Hospital__c hosp = [
                SELECT Id, Contact_Email__c, CC_Email_Address__c 
                FROM Hospital__c 
                WHERE Id = :invoice.Hospital__c
            ];
            
            if (hosp.Contact_Email__c != null) {
                emailAddresses.add(hosp.Contact_Email__c);
            }
            if (hosp.CC_Email_Address__c != null) {
                emailAddresses.add(hosp.CC_Email_Address__c);
            }
            
            // Step 4: Get invoice data for email content
            invoice__c curInvoice = [
                SELECT Id, Name, BillingAccountId__r.Business_Owner__r.Name, 
                Hospital__r.Name, Delivery_Challan__r.Name 
                FROM invoice__c 
                WHERE Id = :invoice.Id
            ];
            
            // Step 5: Send notifications
            if (!userIds.isEmpty()) {
                String subject = 'New Invoice Generated: ' + curInvoice.Name;
                
                String body = 'Dear User,\n\n'
                    + 'A new invoice record "' + curInvoice.Name + '" has been successfully created for your reference.\n\n'
                    + 'Details:\n'
                    + '- Against Delivery Challan: ' + curInvoice.Delivery_Challan__r.Name + '\n'
                    + '- Generated By: ' + curInvoice.BillingAccountId__r.Business_Owner__r.Name + '\n'
                    + '- Invoiced To Hospital: ' + curInvoice.Hospital__r.Name + '\n\n'
                    + 'Please take appropriate action as needed.\n\n'
                    + 'Best regards,\nZydus DMS';
                
                // Convert Ids to Strings
                Set<String> stringUserIds = new Set<String>();
                for (Id uid : userIds) {
                    stringUserIds.add(String.valueOf(uid));
                }
                
                NotificationService.notifyUsers(
                    stringUserIds,
                    curInvoice.Id,
                    subject,
                    body
                );
                
                if (!emailAddresses.isEmpty()) {
                    NotificationService.sendEmail(emailAddresses, subject, body);
                }
            }
            
            return invoice.Id;
            
        } catch (Exception e) {
            System.debug('Exception in saveInvoice: ' + e.getMessage());
            throw new AuraHandledException('Failed to save invoice: ' + e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static List<String> existingDoctor(String keyword) {
        
        Id currUser=UserInfo.getUserId();
        Account currAcc=[SELECT Id FROM Account WHERE Business_Owner__c=:currUser LIMIT 1];
        
        Set<String> doctorNames = new Set<String>();
        
        if (String.isNotBlank(keyword)) {
            for (Invoice__c invoice : [
                SELECT Doctor_Name__c FROM Invoice__c 
                WHERE Doctor_Name__c != null AND 
                Doctor_Name__c LIKE :('%' + keyword + '%')
            ]) {
                doctorNames.add(invoice.Doctor_Name__c);
            }
        } else {
            for (Invoice__c invoice : [
                SELECT Doctor_Name__c FROM Invoice__c 
                WHERE Doctor_Name__c != null
            ]) {
                doctorNames.add(invoice.Doctor_Name__c);
            }
        }
        return new List<String>(doctorNames);
    }
    
    @AuraEnabled 
    public static List<String> existingCATHNumber(String keyword){
        Id currUser=UserInfo.getUserId();
        Account currAcc=[SELECT Id FROM Account WHERE Business_Owner__c=:currUser LIMIT 1];
        
        Set<String> cathNumbers = new Set<String>();
        
        if (String.isNotBlank(keyword)) {
            for (Invoice__c invoice : [
                SELECT CATH_Number__c FROM Invoice__c 
                WHERE CATH_Number__c != null AND 
                CATH_Number__c LIKE :('%' + keyword + '%') //AND Consignee_Dealer__c =:currAcc.Id
            ]) {
                cathNumbers.add(invoice.CATH_Number__c);
            }
        } else {
            for (Invoice__c invoice : [
                SELECT CATH_Number__c FROM Invoice__c 
                WHERE CATH_Number__c != null //AND Consignee_Dealer__c =:currAcc.Id
            ]) {
                cathNumbers.add(invoice.CATH_Number__c);
            }
        }
        return new List<String>(cathNumbers);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Scheme__c> getScheme() {
        return [SELECT Id, Name, Discount_Value__c FROM Scheme__c];
    }
    
    @AuraEnabled
    public static List<Map<String, String>> getCreditNoteOptions(Id consigneeId) {
        Id recordTypeId =[select Id from RecordType where SobjectType = 'Credit_Note__c' and DeveloperName = 'RSO'].Id;
        List<Credit_Note__c> creditNotes = [
            SELECT Id, Amount__c
            FROM Credit_Note__c 
            WHERE Is_used__c = false AND Account__c = :consigneeId AND RecordtypeId = : recordTypeId
        ];
        
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        for (Credit_Note__c cn : creditNotes) {
            options.add(new Map<String, String>{
                'label' => '₹' + String.valueOf(cn.Amount__c),
                    'value' => cn.Id
                    });
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getSubChannelPartnerOptions() {
        
        Account currAccount=[SELECT Id, RecordType.Name FROM Account WHERE Business_Owner__c = :UserInfo.getUserId()];
       	String rtName = currAccount.RecordType.Name;
        
        Set<Id> consigneeDistributorsIds = new Set<Id>();
        
        if (rtName == 'Super Distributor') {
            Set<Id> distributorIds = new Set<Id>();
            
            for (Account dist : [SELECT Id FROM Account WHERE ParentId = :currAccount.Id]) {
                consigneeDistributorsIds.add(dist.Id);
                distributorIds.add(dist.Id);
            }
            
            for (Account subDist : [SELECT Id FROM Account WHERE ParentId IN :distributorIds]) {
                consigneeDistributorsIds.add(subDist.Id);
            }
        } else if (rtName == 'Distributor') {
            for (Account dist : [SELECT Id FROM Account WHERE ParentId = :currAccount.Id]) {
                consigneeDistributorsIds.add(dist.Id);
            }
        }
        
        if (consigneeDistributorsIds.isEmpty()) {
            return new List<Account>();
        }
        
        return [SELECT Id, Name FROM Account WHERE Id IN :consigneeDistributorsIds];
    }
    
    @AuraEnabled
    public static List<Delivery_Challan__c> getDeliveryChallanForChannelPartner(String Id) {
        
        Account currAcc=[SELECT Id FROM Account WHERE Business_Owner__c=:UserInfo.getUserId()];
        
        List<Delivery_Challan__c> allChallans = [
            SELECT Id, Name, Total_Quantity__c, Consignor_Distributor__c,
            Invoiced_To_Hospital_Quantity__c, Invoiced_By_Parent_Account_Quantity__c
            FROM Delivery_Challan__c 
            WHERE Consignee_Distributor__c = : Id
            AND Consignor_Distributor__c = : currAcc.Id
            AND Invoiced_To_Hospital_Quantity__c > 0
        ];
        
        List<Delivery_Challan__c> filtered = new List<Delivery_Challan__c>();
        for (Delivery_Challan__c dc : allChallans) {
            if (dc.Invoiced_By_Parent_Account_Quantity__c < dc.Total_Quantity__c) {
                filtered.add(dc);
            }
        }
        return filtered;
    }
    
    @AuraEnabled
    public static List<Invoice__c> getInvoices(String childAccountId, String relavantDCId) {
        if (String.isBlank(childAccountId) || String.isBlank(relavantDCId)) {
            throw new AuraHandledException('Missing required parameters.');
        }
        
        List<Delivery_Challan_Line_Item__c> dcLineItems = [
            SELECT Serial_Number__c
            FROM Delivery_Challan_Line_Item__c
            WHERE Delivery_Challan__c = :relavantDCId
            AND Serial_Number__c != null AND Is_Invoiced_To_Hospital__c = true AND Is_Invoiced_By_parent_Account__c = false
        ];
        
        Set<String> dcSerialNumbers = new Set<String>();
        for (Delivery_Challan_Line_Item__c dcItem : dcLineItems) {
            dcSerialNumbers.add(dcItem.Serial_Number__c);
        }
        
        if (dcSerialNumbers.isEmpty()) return new List<Invoice__c>();
        
        List<Invoice__c> invoices = [SELECT Id, Name, Consignee_Dealer__c, InvoiceDate__c , Total_Amount__c FROM Invoice__c
                                     WHERE Consignor_Dealer__c = :childAccountId
                                     AND Id IN (SELECT Invoice__c FROM Invoice_Product_Line_Item__c  WHERE Serial_Number__c IN :dcSerialNumbers)];
        system.debug('returning invoices are :'+invoices);
        return invoices;
    }
    
    @AuraEnabled
    public static Invoice__c getInvoiceData(String invoiceId) {
        return [
            SELECT 
            Id,
            Name,
            Patient_First_Name__c,
            Patient_Last_Name__c,
            Patient_Age__c,
            Patient_Gender__c,
            Patient_Register_Number__c,
            Delivery_Challan__c,
            BillingAccountId__c,
            Doctor_Name__c,
            IP_Number__c,
            Comment_Remark__c,
            CATH_Number__c,
            Date_of_Implant__c,
            Invoice_Type__c
            FROM Invoice__c 
            WHERE Id = :invoiceId 
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getPaymentModePicklistValues() {
        List<String> picklistValues = new List<String>();
        try {
            Schema.DescribeFieldResult fieldResult = Invoice__c.Payment_Mode__c.getDescribe();
            List<Schema.PicklistEntry> values = fieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : values) {
                if (entry.isActive()) {
                    picklistValues.add(entry.getLabel());
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching picklist values: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve payment modes: ' + e.getMessage());
        }
        return picklistValues;
    }
    
    public class ChannelPartnerLineItemDTO {
        @AuraEnabled public String Id;
        @AuraEnabled public String serialNumber;
        @AuraEnabled public String dcName;
        @AuraEnabled public String productName;
        @AuraEnabled public Date suppliedDate;
        @AuraEnabled public String status;
        @AuraEnabled public String condition;
        @AuraEnabled public Decimal sgst;
        @AuraEnabled public Decimal cgst;
        @AuraEnabled public Decimal igst;
        @AuraEnabled public Decimal netAmount;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal billDiscountAmount;
    }
    
    @AuraEnabled
    public static List<ChannelPartnerLineItemDTO> getChannelPartnerLineItems(String dcId, String invoiceId) {
        
        Delivery_Challan__c dc = [
            SELECT Id,
            Consignee_Distributor__c,
            Consignor_Distributor__c
            FROM Delivery_Challan__c
            WHERE Id = :dcId
        ];
        
        Map<String, Id> serialToInvp=new Map<String, Id>();
        for(Invoice_Product_Line_Item__c invp: [SELECT Id, Serial_Number__c FROM Invoice_Product_Line_Item__c WHERE Invoice__C=:invoiceId]){
            serialToInvp.put(invp.Serial_Number__c, invp.Id);
        }
        
        
        List<Delivery_Challan_Line_Item__c> dcItems = [
            SELECT Id, Serial_Number__c, Delivery_Challan__r.Name, Zydus_Price_Book_Entry__r.Bill_Discount_Amount__c
            FROM Delivery_Challan_Line_Item__c
            WHERE Delivery_Challan__c = :dcId
            AND Is_Invoiced_To_Hospital__c = true
            AND Is_Invoiced_By_parent_Account__c = false AND Serial_Number__c IN :serialToInvp.keySet()
        ];
        if (dcItems.isEmpty()) return new List<ChannelPartnerLineItemDTO>();
        
        Set<String> serialNumbers = new Set<String>();
        for (Delivery_Challan_Line_Item__c li : dcItems) {
            if (String.isNotBlank(li.Serial_Number__c))
                serialNumbers.add(li.Serial_Number__c);
        }
        if (serialNumbers.isEmpty()) return new List<ChannelPartnerLineItemDTO>();
        
        List<Warehouse__c> whs = [
            SELECT Id
            FROM Warehouse__c
            WHERE Account__r.Business_Owner__c = :UserInfo.getUserId()
        ];
        
        List<Warehouse__c> cosigneeWH = [
            SELECT Id
            FROM Warehouse__c
            WHERE Account__c= : dc.Consignee_Distributor__c
        ];
        Set<Id> consigneewhIds = new Set<Id>();
        for (Warehouse__c w : cosigneeWH) consigneewhIds.add(w.Id);
        
        Map<String, Decimal> consigneeWpMap = new Map<String, Decimal>();
        for (Warehouse_Product_Line_Items__c wp : [
            SELECT Id,
            Serial_Number__c,
            Unit_Price__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Connected_Warehouse__c IN :consigneewhIds
            AND Serial_Number__c IN :serialNumbers
            AND Status__c = 'Consumed'
            AND Condition__c = 'Good'
        ]) {
            consigneeWpMap.put(wp.Serial_Number__c, wp.Unit_Price__c);
        }
        
        
        Set<Id> whIds = new Set<Id>();
        for (Warehouse__c w : whs) whIds.add(w.Id);
        if (whIds.isEmpty()) return new List<ChannelPartnerLineItemDTO>();
        
        Map<String, Warehouse_Product_Line_Items__c> wpMap = new Map<String, Warehouse_Product_Line_Items__c>();
        for (Warehouse_Product_Line_Items__c wp : [
            SELECT Id,
            Serial_Number__c,
            Supplied_Date__c,
            Status__c,
            Condition__c,
            Unit_Price__c,
            Warehouse__r.Zydus_Product__r.Name,
            Warehouse__r.Zydus_Product__r.HSN_Code__c,
            Delivery_Challan_Line_Item__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Connected_Warehouse__c IN :whIds
            AND Serial_Number__c IN :serialNumbers
            AND Status__c = 'Delivered'
            AND Condition__c = 'Good'
        ]) {
            wpMap.put(wp.Serial_Number__c, wp);
        }
        
        String buyerState = [SELECT State__c FROM Account WHERE Id = :dc.Consignee_Distributor__c].State__c;
        String supplierState = [SELECT State__c FROM Account WHERE Id = :dc.Consignor_Distributor__c].State__c;
        String supplyType = buyerState == supplierState ? 'Intra-State' : 'Inter-State';
        
        Set<Id> hsnCodes = new Set<Id>();
        for (Warehouse_Product_Line_Items__c wp : wpMap.values()) {
            Id hsn = wp.Warehouse__r.Zydus_Product__r.HSN_Code__c;
            if (hsn != null) hsnCodes.add(hsn);
        }
        
        Date today = Date.today();
        Map<String, HSN_Tax_Master_Link__c> taxRateMap = new Map<String, HSN_Tax_Master_Link__c>();
        if (!hsnCodes.isEmpty()) {
            for (HSN_Tax_Master_Link__c tax : [
                SELECT HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c, Tax_Master__r.State__c
                FROM HSN_Tax_Master_Link__c
                WHERE HSN_Code__c IN :hsnCodes
                AND Tax_Master__r.Is_Active__c = TRUE
                AND Tax_Master__r.Effective_From__c <= :today
                AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :today)
            ]) {
                String key = tax.HSN_Code__c + '_' + supplierState + '_' + tax.Supply_Type__c;
                taxRateMap.put(key, tax);
            }
        }
        
        List<ChannelPartnerLineItemDTO> result = new List<ChannelPartnerLineItemDTO>();
        
        for (Delivery_Challan_Line_Item__c li : dcItems) {
            ChannelPartnerLineItemDTO dto = new ChannelPartnerLineItemDTO();
            
            dto.serialNumber = li.Serial_Number__c;
            dto.dcName       = li.Delivery_Challan__r?.Name;
            Decimal billDiscountAmount = li.Zydus_Price_Book_Entry__r.Bill_Discount_Amount__c;
            
            Warehouse_Product_Line_Items__c wp = wpMap.get(li.Serial_Number__c);
            if (wp != null) {
                dto.Id           = wp.Id;
                dto.productName  = wp.Warehouse__r?.Zydus_Product__r?.Name;
                dto.suppliedDate = wp.Supplied_Date__c;
                dto.status       = wp.Status__c;
                dto.condition    = wp.Condition__c;
                Decimal unitPrice = consigneeWpMap.get(li.Serial_Number__c)!=null ? consigneeWpMap.get(li.Serial_Number__c) : 0;
                dto.unitPrice = unitPrice;
                
                Decimal cgst = 0, sgst = 0, igst = 0;
                Id   hsnKey = wp.Warehouse__r.Zydus_Product__r.HSN_Code__c;
                String taxKey = hsnKey + '_' + supplierState + '_' + supplyType;
                
                if (taxRateMap.containsKey(taxKey)) {
                    HSN_Tax_Master_Link__c tx = taxRateMap.get(taxKey);
                    if (supplyType == 'Intra-State') {
                        cgst = unitPrice * (tx.CGST__c / 100);
                        sgst = unitPrice * (tx.SGST__c / 100);
                    } else {
                        igst = unitPrice * (tx.IGST__c / 100);
                    }
                }
                dto.netAmount= unitPrice + cgst + sgst + igst;
                dto.cgst = cgst;
                dto.sgst = sgst;
                dto.igst = igst;
                dto.billDiscountAmount = billDiscountAmount;
            } else {
                dto.Id           = null;
                dto.productName  = null;
                dto.suppliedDate = null;
                dto.status       = null;
                dto.condition    = null;
                dto.netAmount    = 0;
                dto.unitPrice    = 0;
                dto.cgst         = 0;
                dto.sgst         = 0;
                dto.igst         = 0;
                dto.billDiscountAmount = 0;
            }
            result.add(dto);
        }
        return result;
    }
    
    @AuraEnabled
    public static Id saveInvoiceCP(String invoiceDataCP, String selectedInvoice) {
        ID userId = UserInfo.getUserId();
        Set<String> userIds = new Set<String>();
        
        Account currentAccount = [
            SELECT Id, Business_Owner__c, ParentId 
            FROM Account 
            WHERE Business_Owner__c = :userId 
            LIMIT 1
        ];
        
        if (currentAccount != null) {
            if (currentAccount.Business_Owner__c != null) {
                userIds.add(currentAccount.Business_Owner__c);
            }
            if (currentAccount.ParentId != null) {
                Id parentUserId = [
                    SELECT Business_Owner__c 
                    FROM Account 
                    WHERE Id = :currentAccount.ParentId 
                    LIMIT 1
                ].Business_Owner__c;
                if (parentUserId != null) userIds.add(parentUserId);
            }
        }
        
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Invoice__c']) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(invoiceDataCP);
            
            String implantDateStr    = (String) data.get('implantDateCP');
            String ipNumber          = (String) data.get('ipNumberCP');
            String cathNumber        = (String) data.get('cathNumberCP');
            String firstName         = (String) data.get('patientFirstNameCP');
            String lastName          = (String) data.get('patientLastNameCP');
            String gender            = (String) data.get('patientGenderCP');
            String doctorName        = (String) data.get('doctorInputCP');
            String invoiceType       = (String) data.get('invoiceType');
            String patientRegisterNumberCP = (String) data.get('patientRegisterNumberCP');
            String accountId         = (String) data.get('selectedChannelPartner');
            String deliveryChallanId = (String) data.get('selectedDeliveryChallan');
            String comment           = data.containsKey('comment') ? (String) data.get('comment') : null;
            String paymentMode       = (String) data.get('paymentMode');
            Integer age              = data.get('patientAgeCP') != null 
                ? Integer.valueOf(data.get('patientAgeCP')) : 0;
            
            Delivery_Challan__c dc = [SELECT Id, Consignee_Distributor__c, Consignor_Distributor__c FROM Delivery_Challan__c WHERE Id=:deliveryChallanId];
            
            
            List<Object> creditNoteObjs = (List<Object>) data.get('creditNoteId');
            List<Id> creditNoteIds = new List<Id>();
            if (creditNoteObjs != null) {
                for (Object obj : creditNoteObjs) {
                    creditNoteIds.add((Id) obj);
                }
            }
            
            Boolean hasExpiredScheme = false;
            List<Object> rawLineItems = (List<Object>) data.get('lineItemIds');
            Map<Id, Map<String, Object>> inputMap = new Map<Id, Map<String, Object>>();
            List<Id> lineItemIds = new List<Id>();
            
            for (Object obj : rawLineItems) {
                if (obj instanceof Map<String,Object>) {
                    Map<String,Object> m = (Map<String,Object>) obj;
                    
                    if (m.containsKey('scheme')) {
                        String scheme = String.valueOf(m.get('scheme'));
                        if (scheme != null && scheme.equalsIgnoreCase('Expiry')) {
                            hasExpiredScheme = true;
                        }
                    }
                    
                    if (m.containsKey('id') && m.get('id') != null) {
                        Id lid = (Id) m.get('id');
                        lineItemIds.add(lid);
                        inputMap.put(lid, m);
                    }
                }
            }
            
            
            Invoice__c invoice = new Invoice__c(
                Patient_First_Name__c   = firstName,
                Patient_Last_Name__c    = lastName,
                Patient_Age__c          = age,
                Patient_Gender__c       = gender,
                Patient_Register_Number__c = patientRegisterNumberCP,
                Doctor_Name__c          = doctorName,
                IP_Number__c            = ipNumber,
                CATH_Number__c          = cathNumber,
                Invoice_Type__c			= invoiceType,
                Delivery_Challan__c     = deliveryChallanId,
                Payment_Mode__c         = paymentMode,
                Comment_Remark__c       = comment,
                Consignee_Dealer__c     = dc.Consignee_Distributor__c,
                Consignor_Dealer__c		= dc.Consignor_Distributor__c,
                InvoiceDate__c          = Date.today()
            );
            
            if (String.isNotBlank(implantDateStr)) {
                invoice.Date_of_Implant__c = Date.valueOf(implantDateStr);
            }
            
            if (String.isNotBlank(selectedInvoice)) {
                invoice.Is_Invoiced_By_Parent__c = true;
            }
            
            String rtName=[SELECT RecordType.Name FROM Account WHERE ID =: dc.Consignee_Distributor__c].RecordType.Name;
            
            Id invoiceRTId = recordTypeMap.get(rtName + ' Invoice');
            if (invoiceRTId == null) {
                throw new AuraHandledException('No matching RecordType found for: ' + rtName);
            }
            invoice.RecordTypeId = invoiceRTId;
            
            invoice.Payment_Status__c = hasExpiredScheme ? 'Draft Invoice' : 'Invoice Created';
            insert invoice;
            
            if (!creditNoteIds.isEmpty()) {
                List<Credit_Note__c> notesToUpdate = [
                    SELECT Id, Is_used__c 
                    FROM Credit_Note__c 
                    WHERE Id IN :creditNoteIds
                ];
                for (Credit_Note__c cn : notesToUpdate) {
                    cn.Is_used__c = true;
                    cn.Invoice__c = invoice.Id;
                }
                update notesToUpdate;
            }
            
            List<Warehouse_Product_Line_Items__c> selectedLineItems = [
                SELECT Id, Warehouse__r.Zydus_Product__c,
                Warehouse__r.Zydus_Product__r.HSN_Code__r.Name,
                Delivery_Challan_Line_Item__c, Manufactured_Date__c,
                Expiry_Date__c, Unit_Price__c, Batch_Number__c, Serial_Number__c
                FROM Warehouse_Product_Line_Items__c
                WHERE Id IN :lineItemIds
            ];
            Set<String> consumedSerialNumberSet = new Set<String>();
            List<Invoice_Product_Line_Item__c> invoiceProducts = new List<Invoice_Product_Line_Item__c>();
            List<Warehouse_Product_Line_Items__c> toUpdateWPL = new List<Warehouse_Product_Line_Items__c>();
            
            for (Warehouse_Product_Line_Items__c item : selectedLineItems) {
                item.Status__c = 'Consumed';
                item.Sold_Date__c = System.today();
                toUpdateWPL.add(item);
                consumedSerialNumberSet.add(item.Serial_Number__c);
                
                Map<String, Object> vals = inputMap.get(item.Id);
                Decimal sgst = 0, cgst = 0, igst = 0, netAmt = 0;
                String scheme = 'No Scheme';
                Decimal billDiscountAmount = 0;
                
                if (vals != null) {
                    if (vals.containsKey('SGST')) sgst = Decimal.valueOf(String.valueOf(vals.get('SGST')));
                    if (vals.containsKey('CGST')) cgst = Decimal.valueOf(String.valueOf(vals.get('CGST')));
                    if (vals.containsKey('IGST')) igst = Decimal.valueOf(String.valueOf(vals.get('IGST')));
                    if (vals.containsKey('netAmount')) netAmt = Decimal.valueOf(String.valueOf(vals.get('netAmount')));
                    if (vals.containsKey('scheme')) scheme = String.valueOf(vals.get('scheme'));
                    if (vals.containsKey('billDiscountAmount')) billDiscountAmount = Decimal.valueOf(String.valueOf(vals.get('billDiscountAmount')));
                }
                
                invoiceProducts.add(new Invoice_Product_Line_Item__c(
                    Invoice__c = invoice.Id,
                    Zydus_Product__c = item.Warehouse__r.Zydus_Product__c,
                    HSN__c = item.Warehouse__r.Zydus_Product__r.HSN_Code__r.Name,
                    Warehouse_Product_Line_Item__c = item.Id,
                    Serial_Number__c = item.Serial_Number__c,
                    Batch_Number__c  = item.Batch_Number__c,
                    CGST__c = cgst,
                    SGST__c = sgst,
                    IGST__c = igst,
                    Bill_Discount_Amount__c	= billDiscountAmount,
                    Net_Amount__c = netAmt,
                    Unit_Price__c = item.Unit_Price__c,
                    Scheme__c = scheme,
                    Expiry_Date__c = item.Expiry_Date__c,
                    Manufacture_Date__c = item.Manufactured_Date__c
                ));
            }
            
            if (!invoiceProducts.isEmpty()) {
                insert invoiceProducts;
            }
            
            if (!toUpdateWPL.isEmpty()) {
                update toUpdateWPL;
                
            }
            
            List<Warehouse__c> cosigneeWH = [
                SELECT Id
                FROM Warehouse__c
                WHERE Account__c= : currentAccount.Id
            ];
            
            List<delivery_challan_line_item__c> toUpdateInvoicedTOHsopitalList = new List<delivery_challan_line_item__c>();
            
            Set<Id> consigneewhIds = new Set<Id>();
            for (Warehouse__c w : cosigneeWH) consigneewhIds.add(w.Id);
            Set<Id> consigneeDCLIs=new Set<Id>();
            Map<String, Decimal> consigneeWpMap = new Map<String, Decimal>();
            for (Warehouse_Product_Line_Items__c wp : [
                SELECT Delivery_Challan_Line_Item__c
                FROM Warehouse_Product_Line_Items__c
                WHERE Connected_Warehouse__c IN :consigneewhIds
                AND Serial_Number__c IN :consumedSerialNumberSet
            ]) {
                consigneeDCLIs.add(wp.Delivery_Challan_Line_Item__c);
            }
            System.debug('consumedSerialNumberSet: '+consumedSerialNumberSet);
            System.debug('consigneeDCLIs: '+consigneeDCLIs);
            
            /*for(delivery_challan_line_item__c cur : [select Id , Is_Invoiced_To_Hospital__c, Is_Invoiced_By_parent_Account__c from delivery_challan_line_item__c 
where Id IN: consigneeDCLIs]){
cur.Is_Invoiced_To_Hospital__c = true;
toUpdateInvoicedTOHsopitalList.add(cur);
}*/
            
            Map<Id, Id> dcliToChallanMap = new Map<Id, Id>();
            for (delivery_challan_line_item__c dcli : [
                SELECT Id, Delivery_Challan__c 
                FROM delivery_challan_line_item__c 
                WHERE Id IN :consigneeDCLIs
            ]) {
                dcliToChallanMap.put(dcli.Id, dcli.Delivery_Challan__c);
            }
            
            Set<Id> challanIds = new Set<Id>(dcliToChallanMap.values());
            
            List<delivery_challan__Share> sharesToInsert = new List<delivery_challan__Share>();
            
            /*for (Id challanId : challanIds) {
                delivery_challan__Share share = new delivery_challan__Share();
                share.ParentId = challanId;
                share.UserOrGroupId = userId;
                share.AccessLevel = 'Edit';
                share.RowCause = Schema.delivery_challan__Share.RowCause.Manual;
                sharesToInsert.add(share);
            }
            
            insert sharesToInsert;*/
            
            List<delivery_challan_line_item__c> toUpdate = new List<delivery_challan_line_item__c>();
            for (delivery_challan_line_item__c dcli : [
                SELECT Id, Is_Invoiced_To_Hospital__c 
                FROM delivery_challan_line_item__c 
                WHERE Id IN :consigneeDCLIs
            ]) {
                dcli.Is_Invoiced_To_Hospital__c = true;
                toUpdate.add(dcli);
            }
            
            update toUpdate;
            
            //delete sharesToInsert;
            
            
            for(delivery_challan_line_item__c cur : [select Id , Is_Invoiced_To_Hospital__c, Is_Invoiced_By_parent_Account__c, Delivery_Challan__r.Consignor_Distributor__r.Business_Owner__c from delivery_challan_line_item__c
                                                     where delivery_challan__c =: deliveryChallanId AND Serial_Number__c IN : consumedSerialNumberSet]){
                                                         system.debug('cur dcil is '+cur);
                                                         cur.Is_Invoiced_To_Hospital__c = true;
                                                         cur.Is_Invoiced_By_parent_Account__c = true;
                                                         userIds.add(cur.Delivery_Challan__r.Consignor_Distributor__r.Business_Owner__c);
                                                         toUpdateInvoicedTOHsopitalList.add(cur);
                                                     }
            if(!toUpdateInvoicedTOHsopitalList.isEmpty()){
                update toUpdateInvoicedTOHsopitalList;
            }
            
            if (invoice.Payment_Status__c == 'Draft Invoice') {
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(invoice.Id);
                req.setProcessDefinitionNameOrId(System.Label.InvoiceApprovalProcess);
                req.setComments('Invoice submitted for approval');
                Approval.process(req);
            }
            
            Invoice__c curInvoice = [
                SELECT Id, Name,
                Consignor_Dealer__r.Business_Owner__c,
                Consignor_Dealer__r.Business_Owner__r.Name,
                Consignor_Dealer__r.Business_Owner__r.Email,
                Consignee_Dealer__r.Business_Owner__c,
                Consignee_Dealer__r.Business_Owner__r.Name,
                Consignee_Dealer__r.Business_Owner__r.Email,
                Delivery_Challan__r.Name
                FROM Invoice__c
                WHERE Id = :invoice.Id
            ];
            
            List<String> emailAddresses = new List<String>();
            
            if (curInvoice.Consignor_Dealer__r.Business_Owner__c != null) {
                userIds.add(curInvoice.Consignor_Dealer__r.Business_Owner__c);
                if (curInvoice.Consignor_Dealer__r.Business_Owner__r.Email != null) {
                    emailAddresses.add(curInvoice.Consignor_Dealer__r.Business_Owner__r.Email);
                }
            }
            
            if (curInvoice.Consignee_Dealer__r.Business_Owner__c != null) {
                userIds.add(curInvoice.Consignee_Dealer__r.Business_Owner__c);
                if (curInvoice.Consignee_Dealer__r.Business_Owner__r.Email != null) {
                    emailAddresses.add(curInvoice.Consignee_Dealer__r.Business_Owner__r.Email);
                }
            }
            
            if (!userIds.isEmpty()) {
                String subject = 'New Invoice Generated: ' + curInvoice.Name;
                String body = 'Dear User,\n\n'
                    + 'A new invoice record "' + curInvoice.Name + '" has been successfully created for your reference.\n\n'
                    + 'Details:\n'
                    + '- Against Delivery Challan: ' + curInvoice.Delivery_Challan__r.Name + '\n'
                    + '- Generated By: ' + curInvoice.Consignor_Dealer__r.Business_Owner__r.Name + '\n'
                    + '- Invoiced To Dealer: ' + curInvoice.Consignee_Dealer__r.Business_Owner__r.Name + '\n\n'
                    + 'Please take the necessary action.\n\n'
                    + 'Best regards,\nZydus DMS';
                
                NotificationService.notifyUsers(userIds, curInvoice.Id, subject, body);
                
                if (!emailAddresses.isEmpty()) {
                    NotificationService.sendEmail(emailAddresses, subject, body);
                }
            }
            return invoice.Id;
            
        } catch (Exception e) {
            System.debug('Exception in saveInvoiceCP: ' + e);
            throw new AuraHandledException('Failed to save CP invoice: ' + e.getMessage());
        }
    }
    
    public class PaymentPayload {
        public Decimal collectedAmt;
        public String paymentMode;
        public Id invoiceId;
        public String comment;
    }
    
    @AuraEnabled
    public static void saveInvoicePaymentDetails(String paymentDetails) {
        try {
            PaymentPayload payload = (PaymentPayload) JSON.deserialize(paymentDetails, PaymentPayload.class);
            
            Decimal collectedAmount = payload.collectedAmt;
            String mode = payload.paymentMode;
            Id invoiceId = payload.invoiceId;
            String comment = payload.comment;
            
            Invoice__c inv = [SELECT Id, Total_Collected_Amount__c, Total_Amount__c, Payment_Status__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
            
            Decimal totalCollectedAmount = (inv.Total_Collected_Amount__c != null ? inv.Total_Collected_Amount__c : 0) + collectedAmount;
            inv.Total_Collected_Amount__c = totalCollectedAmount;
            
            if (totalCollectedAmount == inv.Total_Amount__c) {
                inv.Payment_Status__c = 'Fully Paid';
                inv.Invoice_Closed__c=true;
            } else if( totalCollectedAmount > 0){
                inv.Payment_Status__c = 'Partially Paid';       
            }
            update inv;
            
            Payment__c newPayment = new Payment__c();
            newPayment.Amount__c = collectedAmount; 
            newPayment.Payment_Mode__c = mode;
            newPayment.Invoice__c = invoiceId;
            newPayment.Comments__c = comment;
            
            insert newPayment;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error while saving payment details: ' + e.getMessage());
        }
    }
    
    public static void checkOutstandingCreditLimit(List<Invoice__c> newRec) {
        if (newRec.isEmpty()) return;
        Id hospitalRecordTypeId = Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName()
            .get('Hospital_Invoice')
            .getRecordTypeId();
        
        List<Invoice__c> dealerInvoices = new List<Invoice__c>();
        for (Invoice__c inv : newRec) {
            if (inv.RecordTypeId != hospitalRecordTypeId) {
                dealerInvoices.add(inv);
            }
        }
        
        if (dealerInvoices.isEmpty()) {
            return; 
        }
        
        Id currUserId = UserInfo.getUserId();
        List<Account> accounts = [SELECT Id, Available_Credit_Limit__c FROM Account WHERE Business_Owner__c = :currUserId LIMIT 1];
        
        if (accounts.isEmpty()) {
            return;
        }
        
        Account dealerAcc = accounts[0];
        
        List<Invoice__c> existingInvoices = [SELECT Id, Total_Pending_Amount__c FROM Invoice__c WHERE Consignee_Dealer__c = :dealerAcc.Id];
        
        Decimal totalPending = 0;
        for (Invoice__c inv : existingInvoices) {
            totalPending += inv.Total_Pending_Amount__c != null ? inv.Total_Pending_Amount__c : 0;
        }
        
        Set<Id> newInvoiceIds = new Set<Id>();
        for (Invoice__c inv : dealerInvoices) {
            if (inv.Id != null) newInvoiceIds.add(inv.Id);
        }
        
        Id creditNoteRTId = [SELECT Id FROM RecordType WHERE SobjectType = 'Credit_Note__c' AND DeveloperName = 'Invoice' LIMIT 1].Id;
        
        Map<Id, Decimal> creditNoteMap = new Map<Id, Decimal>();
        
        if (!newInvoiceIds.isEmpty()) {
            for (Credit_Note__c note : [
                SELECT Invoice__c, Amount__c
                FROM Credit_Note__c
                WHERE Invoice__c IN :newInvoiceIds AND RecordTypeId = :creditNoteRTId
            ]) {
                Decimal amount = note.Amount__c != null ? note.Amount__c : 0;
                creditNoteMap.put(note.Invoice__c,creditNoteMap.containsKey(note.Invoice__c) ? creditNoteMap.get(note.Invoice__c) + amount : amount);
            }
        }
        
        Decimal adjustedNew = 0;
        for (Invoice__c inv : dealerInvoices) {
            Decimal orig = inv.Total_Pending_Amount__c != null ? inv.Total_Pending_Amount__c : 0;
            Decimal credit = creditNoteMap.containsKey(inv.Id) ? creditNoteMap.get(inv.Id) : 0;
            adjustedNew += (orig - credit);
        }
        
        Decimal projected = totalPending + adjustedNew;
        
        if (projected > dealerAcc.Available_Credit_Limit__c) {
            for (Invoice__c inv : dealerInvoices) {
                inv.addError('⚠️ Cannot create invoice: Credit limit exceeded.');
            }
        }
    }    
}