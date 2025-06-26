public without sharing class GenerateDeliveryChallan {
    
    @AuraEnabled
    public static String createDeliveryChallan(Id supplyOrderId) {
        try {
            ID userId = UserInfo.getUserId();
            
            Supply_Order__c supplyOrder = [
                SELECT Id, Name, New_Purchase_Order__c, isDCCreated__c,
                Consignee_Distributor__c, Consignee_Hospital__c,Consignee_Hospital__r.Comment_Options__c, Consignor_Distributor__c,Consignor_Distributor__r.Business_owner__c,New_Purchase_Order__r.RecordType.Name,
                Consignee_Hospital__r.Invoice_Comment__c
                FROM Supply_Order__c
                WHERE Id = :supplyOrderId
                LIMIT 1
            ];
            
            Id paretnAccountUserId = supplyOrder.Consignor_Distributor__r.Business_owner__c;
            if(userId != paretnAccountUserId){
                return 'Access denied: Unauthorized entry attempt detected. Please reach out to your system administrator immediately.';
            }
            
            // Step 1: Get RecordType ID for 'DC'
            Map<String, Id> recordTypeMap = new Map<String, Id>();
            for (RecordType rt : [
                SELECT Id, Name FROM RecordType WHERE SObjectType = 'Delivery_Challan__c'
            ]) {
                recordTypeMap.put(rt.Name, rt.Id);
            }
            
            if (!recordTypeMap.containsKey('DC')) {
                return 'Error: RecordType "DC" not found for Delivery Challan.';
            }
            
            if (supplyOrder.isDCCreated__c) {
                return 'The Delivery Challan for this Supply Order has already been generated!';
            }
            Delivery_Challan__c dc = new Delivery_Challan__c();
            // Step 3: Create Delivery Challan
            if(supplyOrder.Consignee_Distributor__c != null && supplyOrder.Consignee_Hospital__c == null && supplyOrder.New_Purchase_Order__r.RecordType.Name != 'Hospital Purchase Order'){
                
                dc.Name = supplyOrder.Name.replace('SO', 'DC');
                dc.Supply_Order__c = supplyOrder.Id;
                dc.DC_Generated_Date__c = System.today();
                dc.Consignee_Distributor__c = supplyOrder.Consignee_Distributor__c;
                dc.Consignor_Distributor__c = supplyOrder.Consignor_Distributor__c;
                dc.RecordTypeId = recordTypeMap.get('DC');
            }else if(supplyOrder.Consignee_Distributor__c == null && supplyOrder.Consignee_Hospital__c != null && supplyOrder.New_Purchase_Order__r.RecordType.Name == 'Hospital Purchase Order'){
                if(supplyOrder.Consignee_Hospital__r.Comment_Options__c != null && supplyOrder.Consignee_Hospital__r.Comment_Options__c.contains('DCL')){
                    if(supplyOrder.Consignee_Hospital__r.Invoice_Comment__c != null){
                       dc.Comment__c = supplyOrder.Consignee_Hospital__r.Invoice_Comment__c;
                    }
                }
                dc.Name = supplyOrder.Name.replace('SO', 'DC');
                dc.Supply_Order__c = supplyOrder.Id;
                dc.DC_Generated_Date__c = System.today();
                dc.Consignee_Hospital__c = supplyOrder.Consignee_Hospital__c;
                dc.Consignor_Distributor__c = supplyOrder.Consignor_Distributor__c;
                dc.RecordTypeId = recordTypeMap.get('HDC');
            }
            insert dc;
            
            // Step 4: Get SO Line Items & SO Products
            List<Supply_Order_Line_Item__c> soLineItems = [
                SELECT Id,Zydus_Product__c, Zydus_Product__r.Name, Net_Amount__c, Batch_Number__c,
                CGST__c, SGST__c, IGST__c, HSN_Code__c, Serial_Number__c,Unit_Price__c,
                Warehouse__c, Name, Expiry_Date__c, Manufacturing_Date__c, List_Price__c, Zydus_Price_Book_Entry__c
                FROM Supply_Order_Line_Item__c
                WHERE Supply_Order__c = :supplyOrder.Id
            ];
            
            List<SO_Product__c> soProducts = [
                SELECT Id, Zydus_Product__c, Zydus_Product__r.Name
                FROM SO_Product__c
                WHERE Supply_Order__c = :supplyOrder.Id
            ];
            
            // Step 5: Create DC Products
            Map<Id, DC_Product__c> productToDCProd = new Map<Id, DC_Product__c>();
            for (SO_Product__c soProd : soProducts) {
                if (soProd.Zydus_Product__c != null && !productToDCProd.containsKey(soProd.Zydus_Product__c)) {
                    productToDCProd.put(soProd.Zydus_Product__c, new DC_Product__c(
                        Name = dc.Name + '-' + soProd.Zydus_Product__r.Name,
                        Delivery_Challan__c = dc.Id,
                        Zydus_Product__c = soProd.Zydus_Product__c
                    ));
                }
            }
            insert productToDCProd.values();
            
            // Step 6: Fetch Purchase Order Products
            List<Purchase_Order_Product__c> POPs = [
                SELECT Id, Quantity__c, Purchase_Order__c, Supplied_Quantity__c, Zydus_Product__c
                FROM Purchase_Order_Product__c
                WHERE Purchase_Order__c = :supplyOrder.New_Purchase_Order__c
            ];
            
            Map<Id, Purchase_Order_Product__c> productToPOPMap = new Map<Id, Purchase_Order_Product__c>();
            Set<Id> poIdSet = new Set<Id>();
            Set<Id> poPOPIdSet = new Set<Id>();
            
            for (Purchase_Order_Product__c pop : POPs) {
                if (pop.Zydus_Product__c != null) {
                    productToPOPMap.put(pop.Zydus_Product__c, pop);
                    poIdSet.add(pop.Purchase_Order__c);
                    poPOPIdSet.add(pop.Id);
                }
            }
            
            // Step 7: Create DC Line Items and update POP supplied quantity
            List<Delivery_Challan_Line_Item__c> dcLineItems = new List<Delivery_Challan_Line_Item__c>();
            List<Purchase_Order_Product__c> POPsToUpdate = new List<Purchase_Order_Product__c>();
            Set<Id> addedPOPIds = new Set<Id>();
            Set<Id> soLineItemsIDSet = new Set<ID>();
            for (Supply_Order_Line_Item__c soItem : soLineItems) {
                if (soItem.Zydus_Product__c == null || !productToDCProd.containsKey(soItem.Zydus_Product__c)) continue;
                
                dcLineItems.add(new Delivery_Challan_Line_Item__c(
                    Delivery_Challan__c = dc.Id,
                    DC_Product__c = productToDCProd.get(soItem.Zydus_Product__c).Id,
                    Zydus_Product__c = soItem.Zydus_Product__c,
                    Net_Amount__c = soItem.Net_Amount__c,
                    CGST__c = soItem.CGST__c,
                    SGST__c = soItem.SGST__c,
                    IGST__c = soItem.IGST__c,
                    Zydus_Price_Book_Entry__c = soItem.Zydus_Price_Book_Entry__c,
                    List_Price__c = soItem.List_Price__c,
                    Unit_Price__c = soItem.Unit_Price__c,
                    HSN_Code__c = soItem.HSN_Code__c,
                    Serial_Number__c = soItem.Serial_Number__c,
                    Batch_Number__c = soItem.Batch_Number__c,
                    Expiry_Date__c = soItem.Expiry_Date__c,
                    Warehouse__c = soItem.Warehouse__c,
                    Manufacturing_Date__c = soItem.Manufacturing_Date__c,
                    Name = soItem.Name.replace('SO', 'DC')
                ));
                soLineItemsIDSet.add(soItem.Id);
                Purchase_Order_Product__c pop = productToPOPMap.get(soItem.Zydus_Product__c);
                if (pop != null) {
                    pop.Supplied_Quantity__c = (pop.Supplied_Quantity__c == null ? 0 : pop.Supplied_Quantity__c) + 1;
                    if (!addedPOPIds.contains(pop.Id)) {
                        POPsToUpdate.add(pop);
                        addedPOPIds.add(pop.Id);
                    }
                }
            }
            
            insert dcLineItems;
            update POPsToUpdate;
            
            
            // Step 8: Mark Supply Order as DC Created
            supplyOrder.isDCCreated__c = true;
            update supplyOrder;
            List<Warehouse_Product_Line_Items__c> toUpdateStatusList = new List<Warehouse_Product_Line_Items__c>();
            for(Warehouse_Product_Line_Items__c curLineItem : [select id,Status__c from Warehouse_Product_Line_Items__c where Supply_Order_Line_Item__c IN : soLineItemsIDSet ]){
                if(curLineItem.Status__c == 'Committed'){
                    curLineItem.Status__c = 'In Transit';
                    toUpdateStatusList.add(curLineItem);
                }
                
            }
            
            // Step 9: Update SO Status of Purchase_Order_Products
            List<Purchase_Order_Product__c> updateStatusList = new List<Purchase_Order_Product__c>();
            for (Purchase_Order_Product__c curPop : [
                SELECT Id, SO_Status__c, Supplied_Quantity__c, Quantity__c
                FROM Purchase_Order_Product__c
                WHERE Id IN :poPOPIdSet
            ]) {
                if (curPop.Supplied_Quantity__c == curPop.Quantity__c) {
                    curPop.SO_Status__c = 'SO Dispatched';
                } else if (curPop.Supplied_Quantity__c != null && curPop.Supplied_Quantity__c > 0) {
                    curPop.SO_Status__c = 'SO Partially Dispatched';
                }
                updateStatusList.add(curPop);
            }
            update updateStatusList;
            
            // Step 10: Update Purchase Order StageName
            List<Purchase_Order__c> toUpdateStageNameList = new List<Purchase_Order__c>();
            for (Purchase_Order__c curPO : [
                SELECT Id, StageName__c, Total_Ordered_Quantity__c, Total_Supplied_Quantity__c
                FROM Purchase_Order__c
                WHERE Id IN :poIdSet
            ]) {
                Decimal total = curPO.Total_Ordered_Quantity__c == null ? 0 : curPO.Total_Ordered_Quantity__c;
                Decimal supplied = curPO.Total_Supplied_Quantity__c == null ? 0 : curPO.Total_Supplied_Quantity__c;
                
                if (total > supplied) {
                    curPO.StageName__c = 'SO Partially Dispatched';
                } else if (total == supplied) {
                    curPO.StageName__c = 'SO Completely Dispatched';
                }
                toUpdateStageNameList.add(curPO);
            }
            update toUpdateStageNameList;
            update toUpdateStatusList;
      
            Delivery_Challan__c curDC = [
                SELECT Id, Name, Supply_Order__c,
                Supply_Order__r.Name,
                Consignee_Distributor__c,
                Consignee_Distributor__r.Business_Owner__c,
                Consignee_Distributor__r.Business_Owner__r.Name,
                Consignee_Distributor__r.Business_Owner__r.Email,
                Consignor_Distributor__c,
                Consignor_Distributor__r.Business_Owner__c,
                Consignor_Distributor__r.Business_Owner__r.Name,
                Consignor_Distributor__r.Business_Owner__r.Email,
                Consignee_Hospital__c
                FROM Delivery_Challan__c 
                WHERE Id = :dc.Id
            ];
            
            Set<String> userIds = new Set<String>();
            List<String> emailAddresses = new List<String>();
            
            List<User> sysAdmins = [
                SELECT Id, Email 
                FROM User 
                WHERE Profile.Name = 'System Administrator' 
                AND IsActive = true
            ];
            
            for(User u:sysAdmins){
                userIds.add(u.Id);
                emailAddresses.add(u.Email);
            }
            
            if (curDC != null) {
                // Consignee user
                if (curDC.Consignee_Distributor__r.Business_Owner__c != null) {
                    userIds.add(curDC.Consignee_Distributor__r.Business_Owner__c);
                    if (curDC.Consignee_Distributor__r.Business_Owner__r.Email != null) {
                        emailAddresses.add(curDC.Consignee_Distributor__r.Business_Owner__r.Email);
                    }
                }
                
                // Consignor user
                if (curDC.Consignor_Distributor__r.Business_Owner__c != null) {
                    userIds.add(curDC.Consignor_Distributor__r.Business_Owner__c);
                    if (curDC.Consignor_Distributor__r.Business_Owner__r.Email != null) {
                        emailAddresses.add(curDC.Consignor_Distributor__r.Business_Owner__r.Email);
                    }
                }
            }
            
            if (!userIds.isEmpty()) {
                String subject = 'New Delivery Challan Generated: ' + curDC.Name;
                
                String body = 'Dear User,\n\n'
                    + 'A new Delivery Challan "' + curDC.Name + '" has been successfully created.\n\n'
                    + 'Details:\n'
                    + '- Generated By: ' + curDC.Consignor_Distributor__r.Business_Owner__r.Name + '\n'
                    + '- Against Supply Order: ' + curDC.Supply_Order__r.Name + '\n\n'
                    + 'Please review and proceed with the next steps.\n\n'
                    + 'Best regards,\nZydus DMS Team';
                
                // Send Notification
                NotificationService.notifyUsers(userIds, curDC.Id, subject, body);
                
                // Send Email
                if (!emailAddresses.isEmpty()) {
                    NotificationService.sendEmail(emailAddresses, subject, body);
                }
            }
            
            
            return 'Delivery Challan created successfully!';
        } catch (Exception ex) {
            return 'Error: ' + ex.getMessage();
        }
    }
    
    @AuraEnabled
    public static Id createDCForHospital(String payload) {
        
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, Name FROM RecordType WHERE SObjectType = 'Delivery_Challan__c'
        ]) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        DCRequest req = (DCRequest) JSON.deserialize(payload, DCRequest.class);
        Delivery_Challan__c dc = new Delivery_Challan__c(
            Name					 = req.deliveryChallanNumber,
            Consignee_Hospital__c    = req.consigneeHospital,
            Consignor_Distributor__c = req.consignorDistributorId,
            DC_Generated_Date__c     = Date.today(),
            recordTypeId             = recordTypeMap.get('HDC')
        );
        insert dc;
        List<DC_Product__c> dcProducts = new List<DC_Product__c>();
        for (ProductWrapper pw : req.products) {
            dcProducts.add(new DC_Product__c(
                Name				= dc.Name + '-' + pw.product,
                Delivery_Challan__c = dc.Id,
                Zydus_Product__c    = pw.productId
            ));
        }
        insert dcProducts;
        Map<String, Id> prodToDcProdId = new Map<String, Id>();
        for (DC_Product__c dp : dcProducts) {
            prodToDcProdId.put(dp.Zydus_Product__c, dp.Id);
        }
        Set<Id> lineItemIds = new Set<Id>();
        for (ProductWrapper pw : req.products) {
            for (LineItemWrapper li : pw.lineItems) {
                lineItemIds.add(li.Id);
            }
        }
        Map<Id, Warehouse_Product_Line_Items__c> lineItemMap = new Map<Id, Warehouse_Product_Line_Items__c>(
            [SELECT Id, Serial_Number__c, Status__c, Expiry_Date__c, Manufactured_Date__c, Warehouse__r.Warehouse__c,
             Batch_Number__c, Delivery_Challan_Line_Item__r.CGST__c, Warehouse__r.Zydus_Product__r.HSN_Code__r.Name,
             Warehouse__r.Zydus_Product__c,
             Delivery_Challan_Line_Item__r.IGST__c, List_Price__c, Delivery_Challan_Line_Item__r.HSN_Code__c,
             Delivery_Challan_Line_Item__r.SGST__c, Delivery_Challan_Line_Item__r.Net_Amount__c,Unit_Price__c
             FROM Warehouse_Product_Line_Items__c
             WHERE Id IN :lineItemIds]
        );
        List<Warehouse_Product_Line_Items__c> wpliToUpdate=new List<Warehouse_Product_Line_Items__c>();
        for(Warehouse_Product_Line_Items__c wpli:lineItemMap.values()){
            if (wpli.Status__c == 'Committed') { 
                wpli.Status__c = 'In Transit';
                wpliToUpdate.add(wpli);
            }
        }
        
        if(!wpliToUpdate.isEmpty()){
            update wpliToUpdate;
        }
        map<Id , Id> zydusPriceBookEntryMap = new Map<Id,Id>();
        String buyerState = [SELECT State__c FROM Hospital__c WHERE Id = :req.consigneeHospital].State__c;
        String supplierState = [SELECT State__c FROM Account WHERE Id = :req.consignorDistributorId].State__c;
        String supplyType = buyerState == supplierState ? 'Intra-State' : 'Inter-State';
     	Id hospitalPriceBookId = [SELECT Id, Zydus_Price_Book__c FROM Hospital__c WHERE Id = :req.consigneeHospital].Zydus_Price_Book__c;
        for(Zydus_Price_Book_Entry__c hospEntry : [select Id, Zydus_Product__c from Zydus_Price_Book_Entry__c where Zydus_Price_Book__c =: hospitalPriceBookId]){
            zydusPriceBookEntryMap.Put(hospEntry.Zydus_Product__c,hospEntry.Id);
        }
        
        Set<Id> productIds = new Set<Id>();
        for (ProductWrapper pw : req.products) {
            productIds.add(pw.productId);
        }
        
        Map<Id, Zydus_Product__c> productMap = new Map<Id, Zydus_Product__c>([
            SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :productIds
        ]);
		
        Set<Id> hsnIds = new Set<Id>();
        for (Zydus_Product__c p : productMap.values()) {
            if (p.HSN_Code__c != null) hsnIds.add(p.HSN_Code__c);
        }
        
        Date today = Date.today();
        Map<String, HSN_Tax_Master_Link__c> taxMap = new Map<String, HSN_Tax_Master_Link__c>();
        if (!hsnIds.isEmpty()) {
            for (HSN_Tax_Master_Link__c tax : [
                SELECT HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c, Tax_Master__r.State__c
                FROM HSN_Tax_Master_Link__c
                WHERE HSN_Code__c IN :hsnIds
                AND Supply_Type__c = :supplyType
                AND Tax_Master__r.Is_Active__c = TRUE
                AND Tax_Master__r.Effective_From__c <= :today
                AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :today)
            ]) {
                String key = tax.HSN_Code__c + '_' + supplierState + '_' + supplyType;
                taxMap.put(key, tax);
            }
        }

        
        List<Delivery_Challan_Line_Item__c> lineItems = new List<Delivery_Challan_Line_Item__c>();
        String ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        Map<Id, Integer> productToSuffix = new Map<Id, Integer>();
        Map<Id, Integer> productToP = new Map<Id, Integer>();
        Integer pCounter = 1;    
        String orderNumber = dc.Name.replace('DC-', '');
        for (ProductWrapper pw : req.products) {
            if (!productToSuffix.containsKey(pw.productId)) {
                productToP.put(pw.productId, pCounter++);
                productToSuffix.put(pw.productId, 1);
            }
            for (LineItemWrapper li : pw.lineItems) {
                Warehouse_Product_Line_Items__c wpLineItem = lineItemMap.get(li.Id);
                Integer suffixIndex = productToSuffix.get(pw.productId);
                String baseSuffix = '';
                Integer temp = suffixIndex;
                while (temp > 0) {
                    Integer rem = Math.mod(temp - 1, 26);
                    baseSuffix = ALPHA.substring(rem, rem + 1) + baseSuffix;
                    temp = (temp - 1) / 26;
                }
                productToSuffix.put(pw.productId, suffixIndex + 1); 
                String name = 'DCP' +  productToP.get(pw.productId) + '/' + orderNumber + '/' + baseSuffix;
                
                
                Zydus_Product__c prod = productMap.get(pw.productId);
                Id hsnCode = prod != null ? prod.HSN_Code__c : null;
                
                String taxKey = hsnCode + '_' + supplierState + '_' + supplyType;
                HSN_Tax_Master_Link__c tax = taxMap.get(taxKey);
                
                Decimal unitPrice = wpLineItem.Unit_Price__c != null ? wpLineItem.Unit_Price__c : 0;
                Decimal cgst = 0, sgst = 0, igst = 0;
                
                if (tax != null) {
                    if (supplyType == 'Intra-State') {
                        cgst = unitPrice * (tax.CGST__c / 100);
                        sgst = unitPrice * (tax.SGST__c / 100);
                    } else {
                        igst = unitPrice * (tax.IGST__c / 100);
                    }
                }
                
                Decimal netAmount = unitPrice + cgst + sgst + igst;
                
                lineItems.add(new Delivery_Challan_Line_Item__c(
                    Delivery_Challan__c = dc.Id,
                    DC_Product__c       = prodToDcProdId.get(pw.productId),
                    Unit_Price__c       = wpLineItem.Unit_Price__c,
                    List_Price__c       = wpLineItem.List_Price__c,
                    Zydus_Product__c    = pw.productId,
                    Serial_Number__c    = wpLineItem.Serial_Number__c,
                    Batch_Number__c		= wpLineItem.Batch_Number__c,
                    Expiry_Date__c      = wpLineItem.Expiry_Date__c,
                    Manufacturing_Date__c = wpLineItem.Manufactured_Date__c,
                    Warehouse__c        = wpLineItem.Warehouse__r.Warehouse__c,
                    Name                = name,
                    CGST__c             = cgst,
                    IGST__c             = igst,
                    HSN_Code__c         = wpLineItem.Warehouse__r.Zydus_Product__r.HSN_Code__c,
                    SGST__c             = sgst,
                    Net_Amount__c       = netAmount,
                    Zydus_Price_Book_Entry__c = zydusPriceBookEntryMap.get(pw.productId)
                ));
            }
        }
        insert lineItems;
        
        Delivery_Challan__c curDC = [
            SELECT Id,
            Name,
            Consignor_Distributor__c,
            Consignor_Distributor__r.Business_Owner__c,
            Consignor_Distributor__r.Business_Owner__r.Name,
            Consignor_Distributor__r.Business_Owner__r.Email,
            Consignee_Hospital__r.CC_Email_Address__c,
            Consignee_Hospital__r.Contact_Email__c,
            Consignee_Distributor__r.Business_Owner__r.Email,
            Consignee_Distributor__r.Business_Owner__c
            FROM Delivery_Challan__c 
            WHERE Id = :dc.Id
        ];
        
        Set<String> userIds = new Set<String>();
        List<String> emailAddresses = new List<String>();
        
        List<User> sysAdmins = [
            SELECT Id, Email 
            FROM User 
            WHERE Profile.Name = 'System Administrator' 
            AND IsActive = true
        ];
        
        for(User u:sysAdmins){
            userIds.add(u.Id);
            emailAddresses.add(u.Email);
        }
        
        if (curDC != null) {
            // Consignee user
            if (curDC.Consignee_Distributor__r.Business_Owner__c != null) {
                userIds.add(curDC.Consignee_Distributor__r.Business_Owner__c);
                if (curDC.Consignee_Distributor__r.Business_Owner__r.Email != null) {
                    emailAddresses.add(curDC.Consignee_Distributor__r.Business_Owner__r.Email);
                }
            }
            
            // Consignor user
            if (curDC.Consignor_Distributor__r.Business_Owner__c != null) {
                userIds.add(curDC.Consignor_Distributor__r.Business_Owner__c);
                if (curDC.Consignor_Distributor__r.Business_Owner__r.Email != null) {
                    emailAddresses.add(curDC.Consignor_Distributor__r.Business_Owner__r.Email);
                }
            }
            
            if(curDC.Consignee_Hospital__r.CC_Email_Address__c!=null){
                emailAddresses.add(curDC.Consignee_Hospital__r.CC_Email_Address__c);
            }
            
            if(curDC.Consignee_Hospital__r.Contact_Email__c!=null){
                emailAddresses.add(curDC.Consignee_Hospital__r.Contact_Email__c);
            }
        }
        
        if (!userIds.isEmpty()) {
            String subject = 'New Delivery Challan Generated: ' + curDC.Name;
            
            String body = 'Dear User,\n\n'
                + 'A new Delivery Challan "' + curDC.Name + '" has been successfully created.\n\n'
                + 'Details:\n'
                + '- Generated By: ' + curDC.Consignor_Distributor__r.Business_Owner__r.Name + '\n'
                + 'Please review and proceed with the next steps.\n\n'
                + 'Best regards,\nZydus DMS Team';
            
            // Send Notification
            NotificationService.notifyUsers(userIds, curDC.Id, subject, body);
            
            // Send Email
            if (!emailAddresses.isEmpty()) {
                NotificationService.sendEmail(emailAddresses, subject, body);
            }
        }
        return dc.Id;
    }
    
    public class DCRequest {
        public String deliveryChallanNumber;
        public String consigneeHospital;
        public String consignorDistributorId;
        public List<ProductWrapper> products;
    }
    public class ProductWrapper {
        public Integer key;
        public String product;
        public String productId;
        public String warehouse;
        public String warehouseName;
        public Integer quantity;
        public List<LineItemWrapper> lineItems;
    }
    
    public class LineItemWrapper {
        public String Id;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Hospital__c> getHospitals() {
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
        } else if (rtName == 'Distributor') {
            List<Account> subDistributors = [
                SELECT Id FROM Account WHERE ParentId = :currentAccount.Id
            ];
            for (Account subDist : subDistributors) {
                relatedAccountIds.add(subDist.Id);
            }
        }
        List<Hospital__c> hospitals = [
            SELECT Id, Name
            FROM Hospital__c
            WHERE Id IN (
                SELECT Hospital__c
                FROM Account_Hospital__c
                WHERE Account__c IN :relatedAccountIds
            )
        ];
        return hospitals;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Warehouse__c> getWarehouses() {
        Id currUserId = UserInfo.getUserId();
        List<Account> ownedAccounts = [
            SELECT Id
            FROM Account
            WHERE Business_Owner__c = :currUserId
        ];
        if (ownedAccounts.isEmpty()) {
            return new List<Warehouse__c>();
        }
        return [
            SELECT Id, Name
            FROM Warehouse__c
            WHERE Account__c IN :ownedAccounts
        ];
    }
    
    @AuraEnabled
    public static String getLatestDCNumber(String name) {
        String[] parts = name != null ? name.split(' ') : new String[0];
        String prefix = parts.size() > 0 ? parts[0] : 'Hospital';
        List<Delivery_Challan__c> existing = [
            SELECT Name FROM Delivery_Challan__c 
            WHERE Name LIKE :('DC-' + prefix + '-%')
            ORDER BY CreatedDate DESC
        ];
        Integer next = 1;
        for (Delivery_Challan__c dc : existing) {
            List<String> nameParts = dc.Name.split('-');
            if (nameParts.size() == 3 && Pattern.matches('\\d+', nameParts[2])) {
                Integer num = Integer.valueOf(nameParts[2]);
                if (num >= next) next = num + 1;
            }
        }
        return 'DC-' + prefix + '-' + String.valueOf(100000 + next).substring(1);
    }
    
    @AuraEnabled 
    public static List<Account> getConsignorName(){
        return [SELECT Id, Name FROM Account WHERE Business_Owner__c=:UserInfo.getUserId()];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Hospital_Product__c> getProducts(String hospitalId) {
        return [
            SELECT Id, Name,
            Zydus_Product__c, Zydus_Product__r.Name
            FROM Hospital_Product__c
            WHERE Hospital__c = :hospitalId
        ];
    }
    
    @AuraEnabled
    public static List<Warehouse_Product_Line_Items__c> getWarehouseLineItems(String productId, String warehouseId) {

        List<Warehouse_Product__c> wps = [
            SELECT Id 
            FROM Warehouse_Product__c 
            WHERE Zydus_Product__c = :productId AND Warehouse__c = :warehouseId
        ];
        Set<Id> wpIds = new Set<Id>();
        for (Warehouse_Product__c wp : wps) {
            wpIds.add(wp.Id);
        }
        if (wpIds.isEmpty()) {
            return new List<Warehouse_Product_Line_Items__c>();
        }
        return [
            SELECT
            Id,
            Name,
            Batch_Number__c,
            unit_price__c,
            Condition__c,
            Connected_Warehouse__c,
            Connected_Warehouse__r.Name,
            Expiry_Date__c,
            GRN__c,
            GRN__r.Name,
            Is_Expired__c,
            Manufactured_Date__c,
            RSO_Created__c,
            Serial_Number__c,
            Sold_Date__c,
            Status__c,
            Supplied_Date__c,
            Warehouse__c,
            Warehouse__r.Name,
            Warehouse__r.Zydus_Product__r.Name
            FROM Warehouse_Product_Line_Items__c
            WHERE Warehouse__c IN :wpIds AND Status__c='Free' AND Condition__c='Good'
        ];
    }
}