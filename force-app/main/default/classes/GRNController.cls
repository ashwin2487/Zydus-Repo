public without sharing class GRNController {
    
    static Integer acceptedProducts=0;
    static Integer rejectedProducts=0;
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDeliveryChallanDetails(Id challanId) {
        System.debug('recordId is ' + challanId);
        Delivery_Challan__c challan = [
            SELECT Id, Consignee_Distributor__c,Consignee_Hospital__c,Consignor_Distributor__c,RecordType.Name
            FROM Delivery_Challan__c
            WHERE Id = :challanId
            LIMIT 1
        ];
        List<Warehouse__c> warehouses = new List<Warehouse__c>();
        
        if (challan.RecordType.Name == 'HDC') {
            warehouses = [
                SELECT Id, Name
                FROM Warehouse__c
                WHERE Hospital__c = :challan.Consignee_Hospital__c
            ];
        } else if (challan.RecordType.Name == 'DC') {
            warehouses = [
                SELECT Id, Name
                FROM Warehouse__c
                WHERE Account__c = :challan.Consignee_Distributor__c
            ];
        }
        
        List<Delivery_Challan_Line_Item__c> items = [
            SELECT Id, Zydus_Product__c, Zydus_Product__r.Name,Serial_Number__c,Batch_Number__c,Expiry_Date__c,Unit_Price__c
            FROM Delivery_Challan_Line_Item__c
            WHERE Delivery_Challan__c = :challanId
        ];
        
        List<Map<String, Object>> lineItemDTOs = new List<Map<String, Object>>();
        for (Delivery_Challan_Line_Item__c item : items) {
            lineItemDTOs.add(new Map<String, Object>{
                'id' => item.Id,
                    'productId' => item.Zydus_Product__c,
                    'productName' => item.Zydus_Product__r.Name,
                    'status' => '', 
                    'rejectionReason' => '',
                    'serialNumber' => item.Serial_Number__c,
                    'batchNumber' => item.Batch_Number__c,
                    'expiryDate' =>item.Expiry_Date__c,
                    'unitPrice' => item.Unit_Price__c
                    });
        }
        
        List<Map<String, String>> warehouseOptions = new List<Map<String, String>>();
        for (Warehouse__c wh : warehouses) {
            warehouseOptions.add(new Map<String, String>{
                'label' => wh.Name,
                    'value' => wh.Id
                    });
        }
        
        return new Map<String, Object>{
            'lineItems' => lineItemDTOs,
                'warehouseOptions' => warehouseOptions
                };             
                    }
    @AuraEnabled
    public static void processGRN(Id challanId, List<Map<String, Object>> lineItems) {
        
        ID userId = UserInfo.getUserId();
        User currentUser = [
            SELECT Id, UserRole.Name , Profile.Name
            FROM User 
            WHERE Id = :userId
            LIMIT 1
        ];
        String userProfile = currentUser.Profile.Name;
        String userRole = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        
        if (!(userRole == 'Super Distributor' || userRole == 'Distributor' || userRole == 'Sub Distributor')) {
            throw new AuraHandledException('Access denied: You do not have permission to perform this action. Please contact your administrator.');
        }
        
        if (lineItems == null || lineItems.isEmpty()) {
            throw new AuraHandledException('No line items provided.');
        }
        
        Map<String, Id> accountRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account']) {
            accountRecordTypeMap.put(rt.Name, rt.Id);
        }
        
        Delivery_Challan__c inProcessDC = [
            SELECT Id, Name, RecordType.DeveloperName, Supply_Order__c, Consignor_Distributor__c, DC_Generated_Date__c,
            Consignor_Distributor__r.RecordTypeId, Consignee_Distributor__c, Consignee_Hospital__c, Consignor_Distributor__r.Business_Owner__c
            FROM Delivery_Challan__c
            WHERE Id = :challanId
            LIMIT 1
        ];

        if (inProcessDC.RecordType.DeveloperName == 'DC') {
            Account consigneeDistributor = [
                SELECT Id, Business_Owner__c, Zydus_Price_Book__c 
                FROM Account 
                WHERE Id = :inProcessDC.Consignee_Distributor__c 
                LIMIT 1
            ];
            
            if (consigneeDistributor.Business_Owner__c != userId) {
                throw new AuraHandledException('Access denied: You are not authorized to create a GRN for this delivery challan.');
            }
            
            Id priceBookId = consigneeDistributor.Zydus_Price_Book__c;
            Map<Id, Decimal> productToPriceMap = new Map<Id, Decimal>();
            
            if (priceBookId != null) {
                for (Zydus_Price_Book_Entry__c entry : [
                    SELECT Zydus_Product__c, Unit_Price__c 
                    FROM Zydus_Price_Book_Entry__c 
                    WHERE Zydus_Price_Book__c = :priceBookId AND Is_Active__c = true
                ]) {
                    productToPriceMap.put(entry.Zydus_Product__c, entry.Unit_Price__c);
                }
            }
            
            Id rtID = [SELECT Id FROM RecordType WHERE SObjectType = 'GRN__c' AND DeveloperName = 'Manual_GRN' LIMIT 1].Id;
            GRN__c grn = new GRN__c(
                Delivery_Challan__c = challanId,
                GRN_Date__c = System.today(),
                RecordTypeId = rtID
            );
            insert grn;
            
            Id SOid = inProcessDC.Supply_Order__c;
            Id consignorAccount = inProcessDC.Consignor_Distributor__c;
            Id consignorRecordTypeId = inProcessDC.Consignor_Distributor__r.RecordTypeId;
            Date dcDate = inProcessDC.DC_Generated_Date__c;
            
            if (consignorRecordTypeId == accountRecordTypeMap.get('Zydus')) {
                List<Supply_Order_Line_Item__c> sooliList = [
                    SELECT Id, Primary_DC__c, Primary_DC__r.is_Moved_To_Warehouse__c
                    FROM Supply_Order_Line_Item__c
                    WHERE Supply_Order__c = :SOid
                ];
                
                if (!sooliList.isEmpty() && sooliList[0].Primary_DC__c != null && !sooliList[0].Primary_DC__r.is_Moved_To_Warehouse__c) {
                    List<Warehouse__c> warehouseList = [
                        SELECT Id 
                        FROM Warehouse__c 
                        WHERE Account__c = :consignorAccount 
                        LIMIT 1
                    ];
                    if (warehouseList.isEmpty()) {
                        throw new AuraHandledException('No warehouse found for consignor account.');
                    }
                    
                    Id consignorWarehouseId = warehouseList[0].Id;
                    
                    List<Primary_DC_Product_Line_Item__c> pdclList = [
                        SELECT Id, Batch_Number__c, Condition__c, Expiry_Date__c, Manufacturing_Date__c,
                        Serial_Number__c, Status__c, Supply_Order_Line_Item__c,
                        Primary_DC_Product__c, Primary_DC_Product__r.Zydus_Product__c, Unit_Price__c, List_Price__c
                        FROM Primary_DC_Product_Line_Item__c
                        WHERE Primary_DC__c = :sooliList[0].Primary_DC__c
                    ];
                    
                    Map<Id, List<Primary_DC_Product_Line_Item__c>> productToPDCLItemsMap = new Map<Id, List<Primary_DC_Product_Line_Item__c>>();
                    Set<Id> pdclProductIds = new Set<Id>();
                    
                    for (Primary_DC_Product_Line_Item__c item : pdclList) {
                        Id productId = item.Primary_DC_Product__r.Zydus_Product__c;
                        if (productId == null) continue;
                        pdclProductIds.add(productId);
                        if (!productToPDCLItemsMap.containsKey(productId)) {
                            productToPDCLItemsMap.put(productId, new List<Primary_DC_Product_Line_Item__c>());
                        }
                        productToPDCLItemsMap.get(productId).add(item);
                    }
                    
                    Map<String, Warehouse_Product__c> productWarehouseMap = new Map<String, Warehouse_Product__c>();
                    for (Warehouse_Product__c wp : [
                        SELECT Id, Zydus_Product__c, Warehouse__c
                        FROM Warehouse_Product__c
                        WHERE Zydus_Product__c IN :pdclProductIds AND Warehouse__c = :consignorWarehouseId
                    ]) {
                        productWarehouseMap.put(wp.Zydus_Product__c + '-' + wp.Warehouse__c, wp);
                    }
                    
                    List<Warehouse_Product__c> toInsertWarehouseProducts = new List<Warehouse_Product__c>();
                    for (Id productId : pdclProductIds) {
                        String key = productId + '-' + consignorWarehouseId;
                        if (!productWarehouseMap.containsKey(key)) {
                            Warehouse_Product__c wp = new Warehouse_Product__c(Zydus_Product__c = productId, Warehouse__c = consignorWarehouseId);
                            toInsertWarehouseProducts.add(wp);
                            productWarehouseMap.put(key, wp);
                        }
                    }
                    if (!toInsertWarehouseProducts.isEmpty()) insert toInsertWarehouseProducts;
                    
                    List<Warehouse_Product_Line_Items__c> wpLineItemsToInsert = new List<Warehouse_Product_Line_Items__c>();
                    for (Id productId : productToPDCLItemsMap.keySet()) {
                        List<Primary_DC_Product_Line_Item__c> pdclItems = productToPDCLItemsMap.get(productId);
                        String key = productId + '-' + consignorWarehouseId;
                        Warehouse_Product__c wp = productWarehouseMap.get(key);
                        
                        for (Primary_DC_Product_Line_Item__c pdclItem : pdclItems) {
                            Decimal finalUnitPrice = productToPriceMap.containsKey(productId)
                                ? productToPriceMap.get(productId)
                                : pdclItem.Unit_Price__c;
                            
                            wpLineItemsToInsert.add(new Warehouse_Product_Line_Items__c(
                                Warehouse__c = wp.Id,
                                Connected_Warehouse__c = consignorWarehouseId,
                                Serial_Number__c = pdclItem.Serial_Number__c,
                                Batch_Number__c = pdclItem.Batch_Number__c,
                                Manufactured_Date__c = pdclItem.Manufacturing_Date__c,
                                Expiry_Date__c = pdclItem.Expiry_Date__c,
                                Condition__c = pdclItem.Condition__c,
                                Status__c = 'Delivered',
                                GRN__c = grn.Id,
                                List_Price__c = pdclItem.List_Price__c,
                                Supply_Order_Line_Item__c = pdclItem.Supply_Order_Line_Item__c,
                                Supplied_Date__c = dcDate,
                                Unit_Price__c = finalUnitPrice
                            ));
                        }
                    }
                    
                    if (!wpLineItemsToInsert.isEmpty()) {
                        insert wpLineItemsToInsert;
                        update new Primary_DC__c(Id = sooliList[0].Primary_DC__c, is_Moved_To_Warehouse__c = true);
                    }
                }
                
                update new Delivery_Challan__c(Id = challanId, isGRNCreated__c = true);
                update new GRN__c(Id = grn.Id, Accepted_Products__c = acceptedProducts, Rejected_Products__c = rejectedProducts);
                
                Account notifyConsigneeAccount = [
                    SELECT Id, Business_Owner__c, Business_Owner__r.Email, Business_Owner__r.Name
                    FROM Account
                    WHERE Id = :inProcessDC.Consignee_Distributor__c
                    LIMIT 1
                ];
                
                Account notifyConsignorAccount = [
                    SELECT Id, Business_Owner__c, Business_Owner__r.Email, Business_Owner__r.Name
                    FROM Account
                    WHERE Id = :inProcessDC.Consignor_Distributor__c
                    LIMIT 1
                ];
                
                Set<String> userIds = new Set<String>();
                List<String> emailAddresses = new List<String>();
                
                if (notifyConsigneeAccount.Business_Owner__c != null) {
                    userIds.add(notifyConsigneeAccount.Business_Owner__c);
                    if (notifyConsigneeAccount.Business_Owner__r.Email != null) {
                        emailAddresses.add(notifyConsigneeAccount.Business_Owner__r.Email);
                    }
                }
                
                if (notifyConsignorAccount.Business_Owner__c != null) {
                    userIds.add(notifyConsignorAccount.Business_Owner__c);
                    if (notifyConsignorAccount.Business_Owner__r.Email != null) {
                        emailAddresses.add(notifyConsignorAccount.Business_Owner__r.Email);
                    }
                }
                
                grn = [
                    SELECT Id, Name, Accepted_Products__c, Rejected_Products__c, Delivery_Challan__r.Name
                    FROM GRN__c
                    WHERE Id = :grn.Id
                ];
                
                if (!userIds.isEmpty()) {
                    String subject = 'New GRN Created: ' + grn.Name;
                    String body = 'Dear User,\n\n'
                        + 'A new GRN (Goods Receipt Note) record "' + grn.Name + '" has been successfully created.\n\n'
                        + 'Details:\n'
                        + '- Accepted Quantity: ' + grn.Accepted_Products__c + '\n'
                        + '- Rejected Quantity: ' + grn.Rejected_Products__c + '\n'
                        + '- Against Delivery Challan: ' + grn.Delivery_Challan__r.Name + '\n\n'
                        + 'Please review the GRN for further actions.\n\n'
                        + 'Best regards,\nZydus DMS';
                    
                    NotificationService.notifyUsers(userIds, grn.Id, subject, body);
                    
                    if (!emailAddresses.isEmpty()) {
                        NotificationService.sendEmail(emailAddresses, subject, body);
                    }
                }
            } else {
                Id consignorWarehouseId = [SELECT Id FROM Warehouse__c WHERE Account__c = :consignorAccount LIMIT 1].Id;
                
                List<Supply_Order_Line_Item__c> soLineItems = [SELECT Id FROM Supply_Order_Line_Item__c WHERE Supply_Order__c = :SOid];
                Set<Id> soLineItemIds = new Set<Id>();
                for (Supply_Order_Line_Item__c item : soLineItems) soLineItemIds.add(item.Id);
                if (!soLineItemIds.isEmpty()) {
                    List<Warehouse_Product_Line_Items__c> lineItemsToUpdate = [
                        SELECT Id, Status__c, Serial_Number__c
                        FROM Warehouse_Product_Line_Items__c
                        WHERE Connected_Warehouse__c = :consignorWarehouseId
                        AND Supply_Order_Line_Item__c IN :soLineItemIds
                        AND Status__c = 'In Transit'
                    ];
                    for (Warehouse_Product_Line_Items__c item : lineItemsToUpdate) {
                        item.Status__c = 'Delivered';
                    }
                    if(!lineItemsToUpdate.isEmpty()){
                        update lineItemsToUpdate;
                    }
                }
            }
            
            Set<Id> productIds = new Set<Id>();
            Set<Id> warehouseIds = new Set<Id>();
            for (Map<String, Object> li : lineItems) {
                productIds.add(Id.valueOf((String) li.get('productId')));
                warehouseIds.add(Id.valueOf((String) li.get('selectedWarehouseId')));
            }
            
            Map<String, Warehouse_Product__c> productWarehouseMap = new Map<String, Warehouse_Product__c>();
            for (Warehouse_Product__c wp : [
                SELECT Id, Zydus_Product__c, Warehouse__c
                FROM Warehouse_Product__c
                WHERE Zydus_Product__c IN :productIds AND Warehouse__c IN :warehouseIds
            ]) {
                productWarehouseMap.put(wp.Zydus_Product__c + '-' + wp.Warehouse__c, wp);
            }
            
            List<Warehouse_Product__c> toInsertWarehouseProducts = new List<Warehouse_Product__c>();
            for (Id productId : productIds) {
                for (Id warehouseId : warehouseIds) {
                    String key = productId + '-' + warehouseId;
                    if (!productWarehouseMap.containsKey(key)) {
                        Warehouse_Product__c wp = new Warehouse_Product__c(Zydus_Product__c = productId, Warehouse__c = warehouseId);
                        toInsertWarehouseProducts.add(wp);
                        productWarehouseMap.put(key, wp);
                    }
                }
            }
            if (!toInsertWarehouseProducts.isEmpty()) insert toInsertWarehouseProducts;
            
            Delivery_Challan__c curDC = [
                SELECT Id, Consignee_Distributor__c, DC_Generated_Date__c,
                (SELECT Id, Expiry_Date__c, Serial_Number__c, Batch_Number__c, Manufacturing_Date__c, Unit_Price__c, List_Price__c
                 FROM Delivery_Challan_Line_Items__r)
                FROM Delivery_Challan__c
                WHERE Id = :challanId
                LIMIT 1
            ];
            Map<String, Delivery_Challan_Line_Item__c> dcLineItemMap = new Map<String, Delivery_Challan_Line_Item__c>();
            for (Delivery_Challan_Line_Item__c item : curDC.Delivery_Challan_Line_Items__r) {
                dcLineItemMap.put(item.Serial_Number__c, item);
            }
            
            List<Warehouse_Product_Line_Items__c> toInsertLineItems = new List<Warehouse_Product_Line_Items__c>();
            Integer acceptedProducts = 0;
            Integer rejectedProducts = 0;
            
            for (Map<String, Object> li : lineItems) {
                Id productId = Id.valueOf((String) li.get('productId'));
                Id warehouseId = Id.valueOf((String) li.get('selectedWarehouseId'));
                String status = (String) li.get('status');
                String rejectionReason = (String) li.get('rejectionReason');
                String serialNumber = (String) li.get('serialNumber');
                String rejectionComment = (String) li.get('rejectionComment');
                
                String key = productId + '-' + warehouseId;
                Warehouse_Product__c wp = productWarehouseMap.get(key);
                Delivery_Challan_Line_Item__c dcItem = dcLineItemMap.get(serialNumber);
                
                Warehouse_Product_Line_Items__c item = new Warehouse_Product_Line_Items__c(
                    GRN__c = grn.Id,
                    Warehouse__c = wp.Id,
                    Connected_Warehouse__c = warehouseId,
                    List_Price__c = dcItem?.List_Price__c,
                    Unit_Price__c = dcItem?.Unit_Price__c,
                    Serial_Number__c = dcItem?.Serial_Number__c,
                    Batch_Number__c = dcItem?.Batch_Number__c,
                    Supplied_Date__c = curDC.DC_Generated_Date__c,
                    Manufactured_Date__c = dcItem?.Manufacturing_Date__c,
                    Expiry_Date__c = dcItem?.Expiry_Date__c,
                    Condition__c = status == 'Rejected' ? (rejectionReason == 'Others' ? 'Others' : rejectionReason) : 'Good',
                    Status__c = 'Free',
                    Delivery_Challan_Line_Item__c = dcItem.Id,
                    Rejection_Comment__c = (status == 'Rejected' && rejectionReason == 'Others') ? rejectionComment : null
                );
                
                
                if (status == 'Accepted') acceptedProducts++;
                if (status == 'Rejected') rejectedProducts++;
                
                toInsertLineItems.add(item);
            }
            
            if (!toInsertLineItems.isEmpty()) insert toInsertLineItems;
            
            update new Delivery_Challan__c(Id = challanId, isGRNCreated__c = true);
            update new GRN__c(Id = grn.Id, Accepted_Products__c = acceptedProducts, Rejected_Products__c = rejectedProducts);
            
            Account notifyConsigneeAccount = [
                SELECT Id, Business_Owner__c, Business_Owner__r.Email, Business_Owner__r.Name 
                FROM Account 
                WHERE Id = :inProcessDC.Consignee_Distributor__c 
                LIMIT 1
            ];
            
            Account notifyConsignorAccount = [
                SELECT Id, Business_Owner__c, Business_Owner__r.Email, Business_Owner__r.Name 
                FROM Account 
                WHERE Id = :inProcessDC.Consignor_Distributor__c 
                LIMIT 1
            ];
            
            Set<String> userIds = new Set<String>();
            List<String> emailAddresses = new List<String>();
            
            if (notifyConsigneeAccount.Business_Owner__c != null) {
                userIds.add(notifyConsigneeAccount.Business_Owner__c);
                if (notifyConsigneeAccount.Business_Owner__r.Email != null) {
                    emailAddresses.add(notifyConsigneeAccount.Business_Owner__r.Email);
                }
            }
            
            if (notifyConsignorAccount.Business_Owner__c != null) {
                userIds.add(notifyConsignorAccount.Business_Owner__c);
                if (notifyConsignorAccount.Business_Owner__r.Email != null) {
                    emailAddresses.add(notifyConsignorAccount.Business_Owner__r.Email);
                }
            }
            
            grn = [
                SELECT Id, Name, Accepted_Products__c, Rejected_Products__c, Delivery_Challan__r.Name 
                FROM GRN__c 
                WHERE Id = :grn.Id
            ];
            
            if (!userIds.isEmpty()) {
                String subject = 'New GRN Created: ' + grn.Name;
                
                String body = 'Dear User,\n\n'
                    + 'A new GRN (Goods Receipt Note) record "' + grn.Name + '" has been successfully created.\n\n'
                    + 'Details:\n'
                    + '- Accepted Quantity: ' + grn.Accepted_Products__c + '\n'
                    + '- Rejected Quantity: ' + grn.Rejected_Products__c + '\n'
                    + '- Against Delivery Challan: ' + grn.Delivery_Challan__r.Name + '\n\n'
                    + 'Please review the GRN for further actions.\n\n'
                    + 'Best regards,\nZydus DMS';
                
                // Notification
                NotificationService.notifyUsers(userIds, grn.Id, subject, body);
                
                // Email
                if (!emailAddresses.isEmpty()) {
                    NotificationService.sendEmail(emailAddresses, subject, body);
                }
            }
            
        }
    }   
}