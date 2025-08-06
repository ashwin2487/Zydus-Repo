public class FirstOrderCreationQueueHospital implements Queueable {
    private List<Id> hospitalIds;
    
    public FirstOrderCreationQueueHospital(List<Id> hospitalIds) {
        this.hospitalIds = hospitalIds;
    }
    
    public void execute(QueueableContext context) {
        // Query all hospitals with the relevant data
        List<Hospital__c> hospitals = [
            SELECT Id, Name, Zydus_Price_Book__c, L1_Approved__c, L2_Approved__c, Active__c,
            Comment_Options__c, Invoice_Comment__c, State__c,
            (SELECT Id, Account__c, Account__r.RecordType.Name, Account__r.Business_Owner__c, Account__r.State__c 
             FROM Account_Hospitals__r)
            FROM Hospital__c
            WHERE Id IN :hospitalIds
        ];
        
        if (hospitals.isEmpty()) return;
        
        Map<Id, Hospital__c> hospitalMap = new Map<Id, Hospital__c>();
        for (Hospital__c h : hospitals) {
            hospitalMap.put(h.Id, h);
        }
        
        // Query Record Types in bulk to avoid nested queries
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, Name FROM RecordType WHERE SObjectType = 'Purchase_Order__c'
        ]) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        
        Id purchaseOrderRtId = recordTypeMap.get('Hospital Purchase Order');
        if (purchaseOrderRtId == null) return;
        
        List<Purchase_Order__c> poToInsert = new List<Purchase_Order__c>();
        Set<Id> pricebookIds = new Set<Id>();
        Map<Id, Account> hospitalToSupplierMap = new Map<Id, Account>();
        
        // Process each hospital individually
        for (Hospital__c hosp : hospitals) {
            if (!(hosp.Active__c && hosp.L1_Approved__c && hosp.L2_Approved__c && hosp.Zydus_Price_Book__c != null)) continue;
            
            Account selectedAccount = null;  // Reset for each hospital
            
            // Collect all the account types for this hospital
            List<Account_Hospital__c> accountHospitals = hosp.Account_Hospitals__r;
            
            // Loop through the account hospitals to select the highest priority account
            for (Account_Hospital__c ah : accountHospitals) {
                String rtName = ah.Account__r.RecordType.Name;
                
                // Check for Sub Distributor first
                if (rtName == 'Sub Distributor' && selectedAccount == null) {
                    selectedAccount = ah.Account__r;
                    break;  // If found, no need to check further
                }
            }
            
            // If no Sub Distributor, check for Distributor
            if (selectedAccount == null) {
                for (Account_Hospital__c ah : accountHospitals) {
                    String rtName = ah.Account__r.RecordType.Name;
                    if (rtName == 'Distributor' && selectedAccount == null) {
                        selectedAccount = ah.Account__r;
                        break;  // If found, no need to check further
                    }
                }
            }
            
            // If neither Sub Distributor nor Distributor, check for Super Distributor
            if (selectedAccount == null) {
                for (Account_Hospital__c ah : accountHospitals) {
                    String rtName = ah.Account__r.RecordType.Name;
                    if (rtName == 'Super Distributor' && selectedAccount == null) {
                        selectedAccount = ah.Account__r;
                        break;  // If found, no need to check further
                    }
                }
            }
            
            // If no account selected, log and continue with next hospital
            if (selectedAccount == null) {
                System.debug('No account of the specified types was found for hospital: ' + hosp.Name);
                continue;
            }
            
            // Proceed to create purchase order
            if (selectedAccount != null && selectedAccount.Business_Owner__c != null) {
                Boolean hasPOL = hosp.Comment_Options__c != null && hosp.Comment_Options__c.contains('POL');
                
                Purchase_Order__c po = new Purchase_Order__c();
                po.Name = generateNextPOName(hosp.Name);
                po.Hospital__c = hosp.Id;
                po.Zydus_Price_Book__c = hosp.Zydus_Price_Book__c;
                po.RecordTypeId = purchaseOrderRtId;
                po.Supplier_Distributor__c = selectedAccount.Id;
                po.StageName__c = 'Approve Purchase Order';
                po.ARS_Order__c = true;
                po.Account__c = selectedAccount.Id;
                po.Comment__c = hasPOL ? hosp.Invoice_Comment__c : null;
                
                poToInsert.add(po);
                pricebookIds.add(hosp.Zydus_Price_Book__c);
                hospitalToSupplierMap.put(hosp.Id, selectedAccount);
            }
        }
        
        // Insert the purchase orders
        if (!poToInsert.isEmpty()) {
            insert poToInsert;
        }
        
        List<Zydus_Price_Book_Entry__c> pbes = [
            SELECT Id, Zydus_Product__c, Zydus_Product__r.MRP__c, Bill_Discount_Amount__c, Unit_Price__c,
            Minimum_Order_Quantity_MOQ__c, Credit_Note_Amount__c, Zydus_Price_Book__c,
            Is_Active__c
            FROM Zydus_Price_Book_Entry__c
            WHERE Zydus_Price_Book__c IN :pricebookIds AND Is_Active__c = TRUE
        ];
        
        Set<Id> productIds = new Set<Id>();
        for (Zydus_Price_Book_Entry__c pbe : pbes) {
            productIds.add(pbe.Zydus_Product__c);
        }
        
        Map<Id, Id> productToHSNMap = new Map<Id, Id>();
        Set<Id> hsnIds = new Set<Id>();
        for (Zydus_Product__c zp : [
            SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :productIds
        ]) {
            if (zp.HSN_Code__c != null) {
                productToHSNMap.put(zp.Id, zp.HSN_Code__c);
                hsnIds.add(zp.HSN_Code__c);
            }
        }
        
        Date today = Date.today();
        Map<String, HSN_Tax_Master_Link__c> taxRateMap = new Map<String, HSN_Tax_Master_Link__c>();
        for (HSN_Tax_Master_Link__c tax : [
            SELECT Id, HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c, Tax_Master__r.State__c
            FROM HSN_Tax_Master_Link__c
            WHERE HSN_Code__c IN :hsnIds
            AND Is_Active__c = TRUE
            AND Tax_Master__r.Is_Active__c = TRUE
            AND Tax_Master__r.Effective_From__c <= :today
            AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :today)
            AND HSN_Code__r.Is_Active__c = TRUE
        ]) {
            String key = tax.HSN_Code__c + '_' + tax.Tax_Master__r.State__c + '_' + tax.Supply_Type__c;
            taxRateMap.put(key, tax);
        }
        
        List<Purchase_Order_Product__c> popToInsert = new List<Purchase_Order_Product__c>();
        List<Id> listPOIds=new List<Id>();
        for (Purchase_Order__c po : poToInsert) {
            listPOIds.add(po.Id);
            List<Zydus_Price_Book_Entry__c> entries = new List<Zydus_Price_Book_Entry__c>();
            for (Zydus_Price_Book_Entry__c pbe : pbes) {
                if (pbe.Zydus_Price_Book__c == po.Zydus_Price_Book__c) {
                    entries.add(pbe);
                }
            }
            
            Hospital__c hosp = hospitalMap.get(po.Hospital__c);
            Account supplier = hospitalToSupplierMap.get(hosp.Id);
            
            String buyerState = hosp.State__c;
            String supplierState = supplier.State__c;
            String supplyType = buyerState == supplierState ? 'Intra-State' : 'Inter-State';
            
            for (Zydus_Price_Book_Entry__c pbe : entries) {
                Id hsnId = productToHSNMap.get(pbe.Zydus_Product__c);
                if (hsnId == null) continue;
                
                String taxKey = hsnId + '_' + supplierState + '_' + supplyType;
                HSN_Tax_Master_Link__c tax = taxRateMap.get(taxKey);
                
                Decimal qty = pbe.Minimum_Order_Quantity_MOQ__c != null ? pbe.Minimum_Order_Quantity_MOQ__c : 1;
                Decimal taxable = qty * pbe.Unit_Price__c;
                
                Decimal cgst = 0, sgst = 0, igst = 0;
                if (tax != null) {
                    if (supplyType == 'Intra-State') {
                        cgst = taxable * (tax.CGST__c / 100);
                        sgst = taxable * (tax.SGST__c / 100);
                    } else {
                        igst = taxable * (tax.IGST__c / 100);
                    }
                }
                
                Purchase_Order_Product__c pop = new Purchase_Order_Product__c();
                pop.Purchase_Order__c = po.Id;
                pop.Zydus_Product__c = pbe.Zydus_Product__c;
                pop.Quantity__c = qty;
                pop.UnitPrice__c = pbe.Unit_Price__c;
                pop.List_Price__c = pbe.Zydus_Product__r.MRP__c;
                pop.SO_Status__c = 'SO Pending';
                pop.Pending_Quantity__c = qty;
                pop.Zydus_Price_Book_Entry__c = pbe.Id;
                pop.Zydus_Price_Book__c = pbe.Zydus_Price_Book__c;
                pop.CGST__c = cgst;
                pop.SGST__c = sgst;
                pop.IGST__c = igst;
                pop.HSN_Code__c = hsnId;
                popToInsert.add(pop);
            }
        }
       
        List<Purchase_Order__c> purchaseOrders = [
            SELECT Id, Name, 
            Account__r.Business_Owner__c, 
            Account__r.Business_Owner__r.Name, 
            Account__r.Business_Owner__r.Email,
            Hospital__r.Contact_Email__c,
            Hospital__r.CC_Email_Address__c
            FROM Purchase_Order__c 
            WHERE Id IN :listPOIds
        ];
        
        Set<String> userIdsToNotify = new Set<String>();
        List<String> emailsToSend = new List<String>();
        
        String subject = 'New Purchase Order: ' + purchaseOrders[0].Name;
        String body = 'Dear User,\n\n' +
            'We are pleased to inform you that a new Purchase Order (' + purchaseOrders[0].Name +
            ') has been successfully created in the Zydus DMS.\n\n' +
            'You may review the Purchase Order details at your convenience.\n\n' +
            'Best regards,\n' +
            'Zydus DMS Team'; 
        
        for (Purchase_Order__c po : purchaseOrders) {
            if(po.Account__r!=null && po.Account__r.Business_Owner__c!=null){
                userIdsToNotify.add(po.Account__r.Business_Owner__c);
            }
            
            if(po.Account__r!=null && po.Account__r.Business_Owner__r!=null && po.Account__r.Business_Owner__r.Email!=null){
                emailsToSend.add(po.Account__r.Business_Owner__r.Email);
            }
            
            if(po.Hospital__r!=null && po.Hospital__r.Contact_Email__c !=null){
                emailsToSend.add(po.Hospital__r.Contact_Email__c);
            }
            
            if(po.Hospital__r!=null && po.Hospital__r.CC_Email_Address__c !=null){
                emailsToSend.add(po.Hospital__r.CC_Email_Address__c);
            }
        }
        
        if(!userIdsToNotify.isEmpty()){
            NotificationService.notifyUsers(userIdsToNotify, purchaseOrders[0].Id, subject, body);                
        }
        if (!emailsToSend.isEmpty()) {
            NotificationService.sendEmail(emailsToSend, subject, body);
        }
        
        if (!popToInsert.isEmpty()) {
            insert popToInsert;
        }
    }
    
    private static String generateNextPOName(String name) {
        String[] parts = name != null ? name.split(' ') : new String[0];
        String prefix = parts.size() > 0 ? parts[0] : 'Hospital';
        List<Purchase_Order__c> existing = [
            SELECT Name FROM Purchase_Order__c 
            WHERE Name LIKE :('PO-' + prefix + '-%')
            ORDER BY CreatedDate DESC
        ];
        Integer next = 1;
        for (Purchase_Order__c po : existing) {
            List<String> nameParts = po.Name.split('-');
            if (nameParts.size() == 3 && Pattern.matches('\\d+', nameParts[2])) {
                Integer num = Integer.valueOf(nameParts[2]);
                if (num >= next) next = num + 1;
            }
        }
        return 'PO-' + prefix + '-' + String.valueOf(100000 + next).substring(1);
    }
}