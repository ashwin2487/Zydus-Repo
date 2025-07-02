public with sharing class OpportunitySupplyOrderHelper {
    @AuraEnabled(cacheable=true)
    public static List<Tax_Master__c> getTaxMasters() {
        try {
            return [
                SELECT Id, Name
                FROM Tax_Master__c
                ORDER BY Name
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Tax Masters: ' + e.getMessage());
        }
    }
    
    public class SupplyOrderLineDTO {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal requestedQty;
        @AuraEnabled public Decimal availableQty;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal cgst;
        @AuraEnabled public Decimal sgst;
        @AuraEnabled public Decimal igst;
        @AuraEnabled public String hsnCode;
        @AuraEnabled public List<WarehouseOption> warehouseOptions;
        @AuraEnabled public Decimal pendingQty;
        @AuraEnabled public Id pricebookEntry;
        @AuraEnabled public Id hsnId;
        
        public SupplyOrderLineDTO(
            Id lineItemId, 
            Id productId, 
            String productName, 
            Decimal requestedQty,
            Decimal availableQty, 
            Decimal unitPrice, 
            Decimal cgst, 
            Decimal sgst, 
            Decimal igst,
            String hsnCode, 
            List<WarehouseOption> warehouseOptions, 
            Decimal pendingQty,
            Id pricebookEntry,
            Id hsnId 
        ) {
            this.lineItemId = lineItemId;
            this.productId = productId;
            this.productName = productName;
            this.requestedQty = requestedQty;
            this.availableQty = availableQty;
            this.unitPrice = unitPrice;
            this.cgst = cgst;
            this.sgst = sgst;
            this.igst = igst;
            this.hsnId = hsnId;
            this.hsnCode = hsnCode;
            this.pendingQty = pendingQty;
            this.pricebookEntry = pricebookEntry;
            this.warehouseOptions = warehouseOptions != null ? warehouseOptions : new List<WarehouseOption>();
        }
    }
    
    public class WarehouseOption {
        @AuraEnabled public String label;
        @AuraEnabled public Id    value;
        @AuraEnabled public Decimal quantity;
        
        public WarehouseOption(String label, Id value, Decimal quantity) {
            this.label = label;
            this.value = value;
            this.quantity = quantity;
        }
    }
    public class SupplyOrderLineInputDTO {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal cgst;
        @AuraEnabled public Decimal sgst;
        @AuraEnabled public Decimal igst;
        @AuraEnabled public Id warehouseId;
        @AuraEnabled public Decimal netAmount;
        @AuraEnabled public Id hsnId;
        @AuraEnabled public Integer availableQty;
        @AuraEnabled public Id pricebookEntry;
        public SupplyOrderLineInputDTO() {}
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SupplyOrderLineDTO> getOpportunityWithWarehouseData(Id purchaseOrderId) {
        Date today = Date.today();
        Map<String, Id> accountRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account']) {
            accountRecordTypeMap.put(rt.Name, rt.Id);
        }
        
        Purchase_Order__c po = [
            SELECT Id, Supplier_Distributor__c, Account__c, RecordTypeId,
            Supplier_Distributor__r.State__c, Account__r.State__c
            FROM Purchase_Order__c
            WHERE Id = :purchaseOrderId
            LIMIT 1
        ];
        if (po == null) {
            throw new AuraHandledException('Purchase Order not found.');
        }
        
        Id supplierId = po.Supplier_Distributor__c;
        Id consigneeId = po.Account__c;
        
        Id supplierRecordTypeId = null;
        if (supplierId != null) {
            Account supplierAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :supplierId LIMIT 1];
            supplierRecordTypeId = supplierAccount.RecordTypeId;
        }
        
        String supplierState = po.Supplier_Distributor__r.State__c;
        String consigneeState = po.Account__r.State__c;
        String supplyType = (supplierState != null && consigneeState != null && supplierState == consigneeState) ? 'Intra-State' : 'Inter-State';
        
        Set<Id> hsnIdsForTaxLookup = new Set<Id>();
        Map<Id, Id> productToHsnId = new Map<Id, Id>();
        
        List<Purchase_Order_Product__c> oliList = [
            SELECT Id,
            Quantity__c,
            UnitPrice__c,
            Zydus_Product__c,
            Zydus_Price_Book__c,
            Zydus_Price_Book_Entry__c,
            Pending_Quantity__c,
            CGST__c, 
            SGST__c, 
            IGST__c, 
            HSN_Code__c,
            HSN_Code__r.Name,
            Zydus_Product__r.HSN_Code__c 
            FROM Purchase_Order_Product__c
            WHERE Purchase_Order__c = :purchaseOrderId
            AND SO_Status__c != 'SO Dispatched'
        ];
        
        Set<Id> productIds = new Set<Id>();
        Set<Id> pricebookIds = new Set<Id>();
        
        for (Purchase_Order_Product__c pop : oliList) {
            if (pop.Zydus_Product__c != null && pop.Zydus_Price_Book__c != null) {
                productIds.add(pop.Zydus_Product__c);
                pricebookIds.add(pop.Zydus_Price_Book__c);
            }
            if (pop.Zydus_Product__r.HSN_Code__c != null) {
                hsnIdsForTaxLookup.add(pop.Zydus_Product__r.HSN_Code__c);
                productToHsnId.put(pop.Zydus_Product__c, pop.Zydus_Product__r.HSN_Code__c);
            }
        }
        
        Map<String, Zydus_Price_Book_Entry__c> pricebookEntryMap = new Map<String, Zydus_Price_Book_Entry__c>();
        if (!productIds.isEmpty() && !pricebookIds.isEmpty()) {
            for (Zydus_Price_Book_Entry__c pbe : [
                SELECT Id, Zydus_Product__c, Zydus_Price_Book__c, List_Price__c,
                Zydus_Product__r.Name
                FROM Zydus_Price_Book_Entry__c
                WHERE Zydus_Product__c IN :productIds
                AND Zydus_Price_Book__c IN :pricebookIds
                AND Is_Active__c = true
            ]) {
                String key = pbe.Zydus_Product__c + '-' + pbe.Zydus_Price_Book__c;
                pricebookEntryMap.put(key, pbe);
            }
        }
        
        Map<Id, HSN_Tax_Master_Link__c> hsnTaxMap = new Map<Id, HSN_Tax_Master_Link__c>();
        if (!hsnIdsForTaxLookup.isEmpty()) {
            for (HSN_Tax_Master_Link__c tax : [
                SELECT Id, HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c, Tax_Master__r.State__c
                FROM HSN_Tax_Master_Link__c
                WHERE HSN_Code__c IN :hsnIdsForTaxLookup
                AND Supply_Type__c = :supplyType
                AND Tax_Master__r.Is_Active__c = TRUE
                AND Tax_Master__r.Effective_From__c <= :today
                AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :today)
            ]) {
                hsnTaxMap.put(tax.HSN_Code__c, tax);
            }
        }
        
        Map<Id, List<WarehouseOption>> prodToWarehouseOptions = new Map<Id, List<WarehouseOption>>();
        
        if (supplierRecordTypeId == accountRecordTypeMap.get('Zydus')) {
            if (supplierId != null && !productIds.isEmpty()) {
                List<Primary_DC_Product_Line_Item__c> dcLineItems = [
                    SELECT Id,
                    Status__c,
                    Condition__c,
                    Primary_DC__c,
                    Primary_DC__r.Name,
                    Primary_DC_Product__r.Zydus_Product__c,
                    Is_Expired__c
                    FROM Primary_DC_Product_Line_Item__c
                    WHERE Primary_DC_Product__r.Zydus_Product__c IN :productIds
                    AND Primary_DC__r.Account__c = :supplierId
                    AND Primary_DC__r.is_Moved_To_Warehouse__c = false
                ];
                
                Map<Id, Map<Id, Integer>> prodToDCToCount = new Map<Id, Map<Id, Integer>>();
                Map<Id, String> dcNames = new Map<Id, String>();
                
                for (Primary_DC_Product_Line_Item__c line : dcLineItems) {
                    if (line.Is_Expired__c == true) continue;
                    if (line.Status__c != 'Free' || line.Condition__c != 'Good') continue;
                    
                    Id prodId = line.Primary_DC_Product__r.Zydus_Product__c;
                    Id dcId = line.Primary_DC__c;
                    String dcName = line.Primary_DC__r.Name;
                    
                    if (!prodToDCToCount.containsKey(prodId)) {
                        prodToDCToCount.put(prodId, new Map<Id, Integer>());
                    }
                    if (!prodToDCToCount.get(prodId).containsKey(dcId)) {
                        prodToDCToCount.get(prodId).put(dcId, 0);
                    }
                    
                    prodToDCToCount.get(prodId).put(dcId, prodToDCToCount.get(prodId).get(dcId) + 1);
                    dcNames.put(dcId, dcName);
                }
                
                for (Id prodId : prodToDCToCount.keySet()) {
                    List<WarehouseOption> options = new List<WarehouseOption>();
                    for (Id dcId : prodToDCToCount.get(prodId).keySet()) {
                        Integer count = prodToDCToCount.get(prodId).get(dcId);
                        String dcName = dcNames.get(dcId);
                        options.add(new WarehouseOption(dcName + ' – ' + count, dcId, Decimal.valueOf(count)));
                    }
                    prodToWarehouseOptions.put(prodId, options);
                }
            }
        } else {
            if (supplierId != null && !productIds.isEmpty()) {
                List<Warehouse_Product_Line_Items__c> lineItems = [
                    SELECT Id,
                    Status__c,
                    Condition__c,
                    Manufactured_Date__c,
                    Warehouse__r.Zydus_Product__c,
                    Warehouse__r.Warehouse__r.Id,
                    Warehouse__r.Warehouse__r.Name,
                    Warehouse__r.Warehouse__r.Account__c,
                    Is_Expired__c
                    FROM Warehouse_Product_Line_Items__c
                    WHERE Warehouse__r.Zydus_Product__c IN :productIds
                    AND Warehouse__r.Warehouse__r.Account__c = :supplierId
                ];
                
                Map<Id, Map<Id, Integer>> prodToWhToCount = new Map<Id, Map<Id, Integer>>();
                Map<Id, String> warehouseNames = new Map<Id, String>();
                
                for (Warehouse_Product_Line_Items__c line : lineItems) {
                    if (line.Is_Expired__c == true) continue;
                    if (line.Status__c != 'Free' || line.Condition__c != 'Good') continue;
                    
                    Id prodId = line.Warehouse__r.Zydus_Product__c;
                    Id whId = line.Warehouse__r.Warehouse__r.Id;
                    String whName = line.Warehouse__r.Warehouse__r.Name;
                    
                    if (!prodToWhToCount.containsKey(prodId)) {
                        prodToWhToCount.put(prodId, new Map<Id, Integer>());
                    }
                    if (!prodToWhToCount.get(prodId).containsKey(whId)) {
                        prodToWhToCount.get(prodId).put(whId, 0);
                    }
                    
                    prodToWhToCount.get(prodId).put(whId, prodToWhToCount.get(prodId).get(whId) + 1);
                    warehouseNames.put(whId, whName);
                }
                
                for (Id prodId : prodToWhToCount.keySet()) {
                    List<WarehouseOption> options = new List<WarehouseOption>();
                    for (Id whId : prodToWhToCount.get(prodId).keySet()) {
                        Integer count = prodToWhToCount.get(prodId).get(whId);
                        String whName = warehouseNames.get(whId);
                        options.add(new WarehouseOption(whName + ' – ' + count, whId, Decimal.valueOf(count)));
                    }
                    prodToWarehouseOptions.put(prodId, options);
                }
            }
        }
        
        List<SupplyOrderLineDTO> dtoList = new List<SupplyOrderLineDTO>();
        
        for (Purchase_Order_Product__c pop : oliList) {
            Id prodId = pop.Zydus_Product__c;
            Id pricebookId = pop.Zydus_Price_Book__c;
            
            if (prodId == null || pricebookId == null) {
                continue;
            }
            
            Decimal unitPrice = pop.UnitPrice__c != null ? pop.UnitPrice__c : 0;
            Decimal qty = pop.Quantity__c != null ? pop.Quantity__c : 0;
            Decimal cgstPct = 0;
            Decimal sgstPct = 0;
            Decimal igstPct = 0;
            
            Id hsnCodeFromProduct = productToHsnId.get(prodId);
            HSN_Tax_Master_Link__c relevantTax = null;
            if (hsnCodeFromProduct != null) {
                relevantTax = hsnTaxMap.get(hsnCodeFromProduct);
            }
            
            if (relevantTax != null) {
                if (supplyType == 'Intra-State') {
                    cgstPct = relevantTax.CGST__c != null ? relevantTax.CGST__c : 0;
                    sgstPct = relevantTax.SGST__c != null ? relevantTax.SGST__c : 0;
                } else {
                    igstPct = relevantTax.IGST__c != null ? relevantTax.IGST__c : 0;
                }
            }
            
            String hsnId = pop.HSN_Code__c != null ? pop.HSN_Code__c : '';
            String hsn = pop.HSN_Code__r != null ? pop.HSN_Code__r.Name : '';
            String prodName = '';
            
            String key = prodId + '-' + pricebookId;
            Zydus_Price_Book_Entry__c pbe = pricebookEntryMap.get(key);
            
            if (pbe != null) {
                prodName = pbe.Zydus_Product__r.Name;
            }
            
            Decimal availableQty = 0;
            List<WarehouseOption> whOptions = prodToWarehouseOptions.get(prodId);
            if (whOptions != null) {
                for (WarehouseOption whOpt : whOptions) {
                    availableQty += whOpt.quantity;
                }
            }
            
            dtoList.add(new SupplyOrderLineDTO(
                pop.Id,
                prodId,
                prodName,          
                pop.Quantity__c,        
                availableQty,
                pop.UnitPrice__c,
                cgstPct, 
                sgstPct, 
                igstPct, 
                hsn,
                whOptions,
                pop.Pending_Quantity__c,
                pbe != null ? pbe.Id : null,
                hsnId
            ));
            
        }
        
        return dtoList;
    }
    
    
    @AuraEnabled
    public static void createSupplyOrderFromOpportunity(Id purchaseOrderId, String linesJson) {
        if (purchaseOrderId == null) {
            throw new AuraHandledException('Purchase Order Id is required.');
        }
        
        Id userId = UserInfo.getUserId();
        
        Purchase_Order__c po = [
            SELECT Id, Name, Supplier_Distributor__c, Account__c, Hospital__c, RecordType.Name,
            Supplier_Distributor__r.RecordTypeId, Account__r.Business_Owner__c
            FROM Purchase_Order__c
            WHERE Id = :purchaseOrderId
            LIMIT 1
        ];
        
        if (po == null) {
            throw new AuraHandledException('Purchase Order not found.');
        }
        
        Account parentAccount = [
            SELECT Id, OwnerId, Business_owner__c
            FROM Account
            WHERE Id = :po.Supplier_Distributor__c
            LIMIT 1
        ];
        
        if (parentAccount.Business_owner__c != userId) {
            throw new AuraHandledException('Access denied: Only the owner of the Parent Account can create a Supply Order.');
        }
        
        User currentUser = [
            SELECT Id, UserRole.Name, Profile.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        String userRole = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        String userProfile = currentUser.Profile != null ? currentUser.Profile.Name : '';
        
        if (!(userRole == 'Super Distributor' || userRole == 'Distributor' || userRole == 'Sub Distributor' || userProfile == 'System Administrator')) {
            throw new AuraHandledException('Access denied: Only Super Distributor, Distributor, Sub Distributor roles, or System Administrators can create Supply Orders.');
        }
        
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account']) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        
        Boolean isARS = po.RecordType != null && (po.RecordType.Name == 'Purchase Order');
        Boolean isHospitalOrder = po.RecordType != null && po.RecordType.Name == 'Hospital Purchase Order';
        
        if (isHospitalOrder && po.Hospital__c == null) {
            throw new AuraHandledException('Hospital is missing on Hospital Purchase Order.');
        }
        
        Supply_Order__c so;
        
        if (recordTypeMap.containsKey('Zydus') && po.Supplier_Distributor__r.RecordTypeId == recordTypeMap.get('Zydus')) {
            Primary_DC__c primaryDC = [
                SELECT Id, is_Moved_To_Warehouse__c, Consignee_Account__c
                FROM Primary_DC__c
                WHERE Account__c = :po.Supplier_Distributor__c AND Consignee_Account__c = :po.Account__c
                LIMIT 1
            ];
            if (primaryDC == null) {
                throw new AuraHandledException('Primary DC record not found for Supplier Distributor.');
            }
            
            so = buildSupplyOrder(po, isARS, isHospitalOrder);
            insert so;
            
            so = [
                SELECT Id, Name, New_Purchase_Order__c, SO_Generated_Date__c, is_ARS_SO__c,
                Consignee_Distributor__r.Business_Owner__c, 
                Consignee_Distributor__r.Business_Owner__r.Email, 
                Consignee_Distributor__r.Business_Owner__r.Name, 
                Consignor_Distributor__r.Business_Owner__c,
                Consignor_Distributor__r.Business_Owner__r.Email, 
                Consignor_Distributor__r.Business_Owner__r.Name,
                New_Purchase_Order__r.Name
                FROM Supply_Order__c
                WHERE Id = :so.Id
            ];
            
            List<SupplyOrderLineInputDTO> lines = parseLinesJson(linesJson);
            createSupplyOrderLineItems(so, lines, primaryDC);
            sendSupplyOrderNotification(so);
            
        } else {
            
            so = buildSupplyOrder(po, isARS, isHospitalOrder);
            insert so;
            
            so = [
                SELECT Id, Name, New_Purchase_Order__c, SO_Generated_Date__c, is_ARS_SO__c,
                Consignee_Distributor__r.Business_Owner__c, 
                Consignee_Distributor__r.Business_Owner__r.Email, 
                Consignee_Distributor__r.Business_Owner__r.Name, 
                Consignor_Distributor__r.Business_Owner__c,
                Consignor_Distributor__r.Business_Owner__r.Email, 
                Consignor_Distributor__r.Business_Owner__r.Name,
                New_Purchase_Order__r.Name
                FROM Supply_Order__c
                WHERE Id = :so.Id
            ];
            
            List<SupplyOrderLineInputDTO> lines = parseLinesJson(linesJson);
            createSupplyOrderLineItems(so, lines, null);
            sendSupplyOrderNotification(so);
        }
    }
    
    private static Supply_Order__c buildSupplyOrder(Purchase_Order__c po, Boolean isARS, Boolean isHospitalOrder) {
        Supply_Order__c so = new Supply_Order__c(
            Name = po.Name.replace('PO','SO'),
            New_Purchase_Order__c = po.Id,
            SO_Generated_Date__c = Date.today(),
            is_ARS_SO__c = isARS,
            Consignor_Distributor__c = po.Supplier_Distributor__c,
            OwnerId = po.Account__r.Business_Owner__c
        );
        
        
        
        
        if (isHospitalOrder) {
            Hospital__c curHospital = [select Id , Comment_Options__c, Invoice_Comment__c from Hospital__c where Id =: po.Hospital__c ];
            if(curHospital.Comment_Options__c != null && curHospital.Comment_Options__c.contains('SOL')){
                if(curHospital.Invoice_Comment__c != null){
                    so.Comment__c = curHospital.Invoice_Comment__c;
                }
                so.Consignee_Hospital__c = po.Hospital__c;
            } 
        }else {
            so.Consignee_Distributor__c = po.Account__c;
        }
        
        return so;
    }
    
    private static List<SupplyOrderLineInputDTO> parseLinesJson(String linesJson) {
        try {
            return (List<SupplyOrderLineInputDTO>) JSON.deserialize(linesJson, List<SupplyOrderLineInputDTO>.class);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid order lines JSON format: ' + e.getMessage());
        }
    }
    
    private static void sendSupplyOrderNotification(Supply_Order__c so) {
        Set<String> userIds = new Set<String>();
        List<String> emailAddresses = new List<String>();
        
        if (so.Consignee_Distributor__r.Business_Owner__c != null) {
            userIds.add(so.Consignee_Distributor__r.Business_Owner__c);
            if (so.Consignee_Distributor__r.Business_Owner__r.Email != null) {
                emailAddresses.add(so.Consignee_Distributor__r.Business_Owner__r.Email);
            }
        }
        if (so.Consignor_Distributor__r.Business_Owner__c != null) {
            userIds.add(so.Consignor_Distributor__r.Business_Owner__c);
            if (so.Consignor_Distributor__r.Business_Owner__r.Email != null) {
                emailAddresses.add(so.Consignor_Distributor__r.Business_Owner__r.Email);
            }
        }
        
        String subject = 'New Supply Order Created: ' + so.Name;
        String body = 'Dear User,\n\n'
            + 'A new Supply Order "' + so.Name + '" has been successfully created.\n\n'
            + 'Details:\n'
            + '- Created By: ' + so.Consignor_Distributor__r.Business_Owner__r.Name + '\n'
            + '- Against Purchase Order: ' + so.New_Purchase_Order__r.Name + '\n\n'
            + 'You may now proceed with the necessary actions.\n\n'
            + 'Best regards,\n Zydus DMS';
        
        NotificationService.notifyUsers(userIds, so.Id, subject, body);
        
        if (!emailAddresses.isEmpty()) {
            NotificationService.sendEmail(emailAddresses, subject, body);
        }
    }
    
    public static void createSupplyOrderLineItems(Supply_Order__c so, List<SupplyOrderLineInputDTO> lines, Primary_DC__c primaryDC) {
        final String ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        
        System.debug('lines'+lines);
        Set<Id> productIds = new Set<Id>();
        Set<Id> warehouseIds = new Set<Id>();
        for (SupplyOrderLineInputDTO dto : lines) {
            if (dto.productId == null) throw new AuraHandledException('Product ID missing for one or more lines.');
            if (dto.warehouseId == null) throw new AuraHandledException('Warehouse not selected for all lines.');
            productIds.add(dto.productId);
            warehouseIds.add(dto.warehouseId);
        }
        
        Map<String, List<Primary_DC_Product_Line_Item__c>> stockMapDC = new Map<String, List<Primary_DC_Product_Line_Item__c>>();
        Map<String, List<Warehouse_Product_Line_Items__c>> stockMapWH = new Map<String, List<Warehouse_Product_Line_Items__c>>();
        
        if (primaryDC != null && !primaryDC.is_Moved_To_Warehouse__c) {
            List<Primary_DC_Product_Line_Item__c> dcStockItems = [
                SELECT Id, Primary_DC_Product__r.Zydus_Product__c, Batch_Number__c, Condition__c, Expiry_Date__c,
                Serial_Number__c, Status__c, Is_Expired__c, Manufacturing_Date__c, Primary_DC_Product__r.Id, List_Price__c, Unit_Price__c
                FROM Primary_DC_Product_Line_Item__c
                WHERE Primary_DC__c = :primaryDC.Id
                AND Primary_DC_Product__r.Zydus_Product__c IN :productIds
                AND Status__c = 'Free'
                AND Condition__c = 'Good'
                AND Is_Expired__c = false
                ORDER BY CreatedDate ASC
            ];
            
            for (Primary_DC_Product_Line_Item__c item : dcStockItems) {
                String key = item.Primary_DC_Product__r.Zydus_Product__c + '-' + primaryDC.Id;
                if (!stockMapDC.containsKey(key)) {
                    stockMapDC.put(key, new List<Primary_DC_Product_Line_Item__c>());
                }
                stockMapDC.get(key).add(item);
            }
        } else {
            List<Warehouse_Product_Line_Items__c> whStockItems = [
                SELECT Id, Warehouse__r.Zydus_Product__c, Warehouse__c, Batch_Number__c, Condition__c, Expiry_Date__c,
                Serial_Number__c, Status__c, Is_Expired__c, Connected_Warehouse__c, Manufactured_Date__c, Unit_Price__c, List_Price__c
                FROM Warehouse_Product_Line_Items__c
                WHERE Status__c = 'Free'
                AND Condition__c = 'Good'
                AND Is_Expired__c = false
                AND Warehouse__r.Zydus_Product__c IN :productIds
                AND Connected_Warehouse__c IN :warehouseIds
                ORDER BY CreatedDate ASC
            ];
            
            for (Warehouse_Product_Line_Items__c item : whStockItems) {
                String key = item.Warehouse__r.Zydus_Product__c + '-' + item.Connected_Warehouse__c;
                if (!stockMapWH.containsKey(key)) {
                    stockMapWH.put(key, new List<Warehouse_Product_Line_Items__c>());
                }
                stockMapWH.get(key).add(item);
            }
        }
        
        Map<Id, SO_Product__c> productToSOProduct = new Map<Id, SO_Product__c>();
        List<SO_Product__c> soProductsToInsert = new List<SO_Product__c>();
        for (Id productId : productIds) {
            soProductsToInsert.add(new SO_Product__c(
                Zydus_Product__c = productId,
                Supply_Order__c = so.Id
            ));
        }
        insert soProductsToInsert;
        for (SO_Product__c sop : soProductsToInsert) {
            productToSOProduct.put(sop.Zydus_Product__c, sop);
        }
        
        Map<Id, Integer> productToP = new Map<Id, Integer>();
        Map<Id, Integer> productToSuffix = new Map<Id, Integer>();
        Integer pCounter = 1;
        
        List<Supply_Order_Line_Item__c> solineItemsToInsert = new List<Supply_Order_Line_Item__c>();
        List<Primary_DC_Product_Line_Item__c> assignedDCStock = new List<Primary_DC_Product_Line_Item__c>();
        List<Warehouse_Product_Line_Items__c> assignedWHStock = new List<Warehouse_Product_Line_Items__c>();
        Set<Id> stockIdsToUpdate = new Set<Id>();
        
        for (SupplyOrderLineInputDTO dto : lines) {
            Integer qty = dto.quantity;
            String key = '';
            if (primaryDC == null) {
                key = dto.productId + '-' + dto.warehouseId;
            } else {
                key = (primaryDC.is_Moved_To_Warehouse__c) ? (dto.productId + '-' + dto.warehouseId) : (dto.productId + '-' + primaryDC.Id);
                    }
            
            if (primaryDC != null && !primaryDC.is_Moved_To_Warehouse__c) {
                if (!stockMapDC.containsKey(key) || stockMapDC.get(key).size() < 1) {
                    throw new AuraHandledException('Not enough available stock for product Id ' + dto.productId);
                }
            } else {
                if (!stockMapWH.containsKey(key) || stockMapWH.get(key).size() < 1) {
                    throw new AuraHandledException('Not enough available stock for product Id ' + dto.productId);
                }
            }
            
            if (!productToP.containsKey(dto.productId)) {
                productToP.put(dto.productId, pCounter++);
                productToSuffix.put(dto.productId, 1);
            }
            
            for (Integer i = 0; i < qty; i++) {
                Integer suffixIndex = productToSuffix.get(dto.productId);
                String baseSuffix = '';
                Integer temp = suffixIndex;
                while (temp > 0) {
                    Integer rem = Math.mod(temp - 1, 26);
                    baseSuffix = ALPHA.substring(rem, rem + 1) + baseSuffix;
                    temp = (temp - 1) / 26;
                }
                productToSuffix.put(dto.productId, suffixIndex + 1);
                
                String orderNumber = so.Name.replace('SO-', '');
                String name = 'SOP' + productToP.get(dto.productId) + '/' + orderNumber + '/' + baseSuffix;
                
                if (primaryDC != null && !primaryDC.is_Moved_To_Warehouse__c) {
                    Primary_DC_Product_Line_Item__c assignedItem = stockMapDC.get(key).remove(0);
                    stockIdsToUpdate.add(assignedItem.Id);
                    
                    solineItemsToInsert.add(new Supply_Order_Line_Item__c(
                        Supply_Order__c = so.Id,
                        SO_Product__c = productToSOProduct.get(dto.productId).Id,
                        Zydus_Product__c = dto.productId,
                        Name = name,
                        CGST__c = dto.cgst,
                        SGST__c = dto.sgst,
                        IGST__c = dto.igst,
                        HSN_Code__c = dto.hsnId,
                        Net_Amount__c = dto.netAmount,
                        Primary_DC__c = primaryDC.Id,
                        Unit_Price__c = dto.unitPrice,
                        Zydus_Price_Book_Entry__c = dto.pricebookEntry,
                        Primary_DC_Product_Line_Item__c = assignedItem.Id,
                        Batch_Number__c = assignedItem.Batch_Number__c,
                        Expiry_Date__c = assignedItem.Expiry_Date__c,
                        Serial_Number__c = assignedItem.Serial_Number__c,
                        Manufacturing_Date__c = assignedItem.Manufacturing_Date__c
                    ));
                    
                    assignedDCStock.add(assignedItem);
                } else {
                    Warehouse_Product_Line_Items__c assignedItem = stockMapWH.get(key).remove(0);
                    stockIdsToUpdate.add(assignedItem.Id);
                    
                    solineItemsToInsert.add(new Supply_Order_Line_Item__c(
                        Supply_Order__c = so.Id,
                        SO_Product__c = productToSOProduct.get(dto.productId).Id,
                        Zydus_Product__c = dto.productId,
                        Name = name,
                        SGST__c = dto.sgst,
                        IGST__c = dto.igst,
                        CGST__c = dto.cgst,
                        HSN_Code__c = dto.hsnId,
                        Net_Amount__c = dto.netAmount,
                        Warehouse__c = dto.warehouseId,
                        Unit_Price__c = dto.unitPrice,
                        Zydus_Price_Book_Entry__c=dto.pricebookEntry,
                        Warehouse_Product_Line_Item__c = assignedItem.Id,
                        Batch_Number__c = assignedItem.Batch_Number__c,
                        Expiry_Date__c = assignedItem.Expiry_Date__c,
                        Serial_Number__c = assignedItem.Serial_Number__c,
                        Manufacturing_Date__c = assignedItem.Manufactured_Date__c
                    ));
                    
                    assignedWHStock.add(assignedItem);
                }
            }
        }
        
        Database.SaveResult[] results = Database.insert(solineItemsToInsert, false);
        Map<Id, Id> stockToSOLIMap = new Map<Id, Id>();
        List<String> errors = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                Supply_Order_Line_Item__c insertedItem = solineItemsToInsert[i];
                if (primaryDC != null && !primaryDC.is_Moved_To_Warehouse__c) {
                    stockToSOLIMap.put(assignedDCStock[i].Id, insertedItem.Id);
                } else {
                    stockToSOLIMap.put(assignedWHStock[i].Id, insertedItem.Id);
                }
            } else {
                for (Database.Error err : results[i].getErrors()) {
                    errors.add('Line item insert error: ' + err.getMessage());
                }
            }
        }
        
        if (!errors.isEmpty()) {
            throw new AuraHandledException('Errors occurred during supply order line item creation: ' + String.join(errors, '; '));
        }
        
        if (!stockToSOLIMap.isEmpty()) {
            if (primaryDC != null && !primaryDC.is_Moved_To_Warehouse__c) {
                List<Primary_DC_Product_Line_Item__c> dcItemsToUpdate = new List<Primary_DC_Product_Line_Item__c>();
                for (Id stockId : stockToSOLIMap.keySet()) {
                    dcItemsToUpdate.add(new Primary_DC_Product_Line_Item__c(
                        Id = stockId,
                        Status__c = 'Committed',
                        Supply_Order_Line_Item__c = stockToSOLIMap.get(stockId)
                    ));
                }
                update dcItemsToUpdate;
            } else {
                List<Warehouse_Product_Line_Items__c> whItemsToUpdate = new List<Warehouse_Product_Line_Items__c>();
                for (Id stockId : stockToSOLIMap.keySet()) {
                    whItemsToUpdate.add(new Warehouse_Product_Line_Items__c(
                        Id = stockId,
                        Status__c = 'Committed',
                        Supply_Order_Line_Item__c = stockToSOLIMap.get(stockId)
                    ));
                }
                update whItemsToUpdate;
            }
        }
        
        Map<Id, Integer> productInsertedQtyMap = new Map<Id, Integer>();
        for (Supply_Order_Line_Item__c soLineItem : solineItemsToInsert) {
            Integer currentQty = productInsertedQtyMap.containsKey(soLineItem.Zydus_Product__c) 
                ? productInsertedQtyMap.get(soLineItem.Zydus_Product__c) 
                : 0;
            productInsertedQtyMap.put(soLineItem.Zydus_Product__c, currentQty + 1);
        }
        List<Purchase_Order_Product__c> popToUpdate = [
            SELECT Id, Pending_Quantity__c, Zydus_Product__c, Quantity__c, SO_Status__c, Purchase_Order__c
            FROM Purchase_Order_Product__c
            WHERE Zydus_Product__c IN :productIds
        ];
        
        List<Purchase_Order_Product__c> popsToStatusUpdate = new List<Purchase_Order_Product__c>();
        for (Purchase_Order_Product__c pop : popToUpdate) {
            Integer deductedQty = productInsertedQtyMap.get(pop.Zydus_Product__c);
            if (deductedQty != null) {
                Decimal currentPendingQty = pop.Pending_Quantity__c != null ? pop.Pending_Quantity__c : 0;
                if (currentPendingQty > 0) {
                    Decimal newPendingQty = currentPendingQty - deductedQty;
                    pop.Pending_Quantity__c = (newPendingQty >= 0) ? newPendingQty : 0;
                }
                
                if (pop.Pending_Quantity__c == 0) {
                    pop.SO_Status__c = 'SO Created';
                } else if (pop.Pending_Quantity__c == pop.Quantity__c) {
                    pop.SO_Status__c = 'SO Pending';
                } else if (pop.Pending_Quantity__c > 0 && pop.Pending_Quantity__c < pop.Quantity__c) {
                    pop.SO_Status__c = 'SO Partially Created';
                }
                popsToStatusUpdate.add(pop);
            }
        }
        
        if(!popsToStatusUpdate.isEmpty()){
            update popsToStatusUpdate;
        }
        
        List<Purchase_Order__c> toUpdateCurList = new List<Purchase_Order__c>();
        
        List<Purchase_Order__c> poList = [SELECT Id, StageName__c, Total_Ordered_Quantity__c, Total_Pending_Quantity__c FROM Purchase_Order__c WHERE Id =: so.New_Purchase_Order__c];
        
        for (Purchase_Order__c curPO : poList) {
            if (curPO.Total_Pending_Quantity__c == 0) {
                curPO.StageName__c = 'SO Created';
            } else if (curPO.Total_Pending_Quantity__c > 0 && curPO.Total_Pending_Quantity__c < curPO.Total_Ordered_Quantity__c) {
                curPO.StageName__c = 'SO Partially Created';
            }
            toUpdateCurList.add(curPO);
        }
        
        if (!toUpdateCurList.isEmpty()) {
            update toUpdateCurList;
        }
    }
}