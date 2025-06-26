public with sharing class SupplyOrderController {
    @AuraEnabled(cacheable=true)
    public static SupplyOrderWrapper getSupplyOrderDetails(Id recordId) {
        // Return empty wrapper if recordId is null
        if (recordId == null) {
            return new SupplyOrderWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
        }
        
        try {
            List<Supply_Order__c> supplyOrders = [
                SELECT Id, Name, Consignee_Distributor__c, Consignee_Hospital__c, Consignor_Distributor__c,
                CreatedById, is_ARS_SO__c, isDCCreated__c, LastModifiedById, mySO__c, Net_Amount__c, 
                OwnerId, pendingSO__c, New_Purchase_Order__c, RecordTypeId, SO_Generated_Date__c,
                soCompleted__c, soDispatch__c, soOfThisMonth__c, Supply_Order__c, 
                Total_CGST__c, Total_IGST__c, Total_Quantity__c, Total_SGST__c, Comment__c,
                
                Consignor_Distributor__r.Name,
                Consignor_Distributor__r.Address__c,
                Consignor_Distributor__r.City__c,
                Consignor_Distributor__r.State__c,
                Consignor_Distributor__r.Account_Pin_Code__c,
                Consignor_Distributor__r.Drug_Licence_Number__c,
                Consignor_Distributor__r.GST_Number__c,
                Consignor_Distributor__r.PAN_Number__c,
                
                Consignee_Distributor__r.Name,
                Consignee_Distributor__r.Address__c,
                Consignee_Distributor__r.State__c,
                Consignee_Distributor__r.City__c,
                Consignee_Distributor__r.Account_Pin_Code__c,
                Consignee_Distributor__r.Drug_Licence_Number__c,
                Consignee_Distributor__r.PAN_Number__c,
                Consignee_Distributor__r.GST_Number__c,
                
                Consignee_Hospital__r.Name,
                Consignee_Hospital__r.Address__c,
                Consignee_Hospital__r.City__c,
                Consignee_Hospital__r.State__c,
                Consignee_Hospital__r.Hospital_Pin_Code__c,
                Consignee_Hospital__r.DL_no__c,
                Consignee_Hospital__r.GST_Number__c,
                Consignee_Hospital__r.PAN_Number__c,
                
                New_Purchase_Order__r.Name,
                New_Purchase_Order__r.CreatedDate,
                
                (
                    SELECT Id, Name, Zydus_Product__c, 
                    Zydus_Product__r.Name, 
                    Zydus_Product__r.Diameter__c, 
                    Zydus_Product__r.Length__c,
                    Zydus_Product__r.Material_Description__c,
                    
                    (
                        SELECT Id, Name, Warehouse__c,
                        Warehouse__r.Address__c,
                        Warehouse__r.City__c,
                        Warehouse__r.State__c,
                        Warehouse__r.ZipCode__c,
                        Serial_Number__c, 
                        Batch_Number__c,
                        Manufacturing_Date__c, 
                        Expiry_Date__c,
                        HSN_Code__r.Name, 
                        Unit_Price__c, 
                        CGST__c,
                        IGST__c, 
                        SGST__c, 
                        Net_Amount__c
                        FROM Supply_Order_Line_Items__r
                    )
                    FROM SO_Products__r
                )
                FROM Supply_Order__c 
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            // If no supply order found, return empty wrapper
            if (supplyOrders.isEmpty()) {
                return new SupplyOrderWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
            }
            
            Supply_Order__c supplyOrder = supplyOrders[0];
            
            // Initialize warehouse lists
            List<Warehouse__c> consignorWarehouses = new List<Warehouse__c>();
            List<Warehouse__c> consigneeWarehouses = new List<Warehouse__c>();
            
            // Fetch consignor warehouses only if Consignor_Distributor__c is not null
            if (supplyOrder.Consignor_Distributor__c != null) {
                try {
                    consignorWarehouses = [
                        SELECT Id, Name, Address__c, City__c, State__c, ZipCode__c 
                        FROM Warehouse__c 
                        WHERE Account__c = :supplyOrder.Consignor_Distributor__c
                        ORDER BY Name ASC NULLS LAST
                    ];
                } catch (Exception e) {
                    System.debug('Error fetching consignor warehouses: ' + e.getMessage());
                    consignorWarehouses = new List<Warehouse__c>();
                }
            }
            
            // Fetch consignee warehouses only if Consignee_Distributor__c is not null
            if (supplyOrder.Consignee_Distributor__c != null) {
                try {
                    consigneeWarehouses = [
                        SELECT Id, Name, Address__c, City__c, State__c, ZipCode__c 
                        FROM Warehouse__c 
                        WHERE Account__c = :supplyOrder.Consignee_Distributor__c
                        ORDER BY Name ASC NULLS LAST
                    ];
                } catch (Exception e) {
                    System.debug('Error fetching consignee warehouses: ' + e.getMessage());
                    consigneeWarehouses = new List<Warehouse__c>();
                }
            }
            
            return new SupplyOrderWrapper(supplyOrder, consignorWarehouses, consigneeWarehouses);
            
        } catch (Exception e) {
            System.debug('Error in getSupplyOrderDetails: ' + e.getMessage());
            // Return empty wrapper in case of any exception
            return new SupplyOrderWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
        }
    }
    
    public class SupplyOrderWrapper {
        @AuraEnabled public Supply_Order__c supplyOrder;
        @AuraEnabled public List<Warehouse__c> consignorWarehouses;
        @AuraEnabled public List<Warehouse__c> consigneeWarehouses;
        
        public SupplyOrderWrapper(Supply_Order__c so, List<Warehouse__c> consignorWh, List<Warehouse__c> consigneeWh) {
            this.supplyOrder = so;
            this.consignorWarehouses = consignorWh != null ? consignorWh : new List<Warehouse__c>();
            this.consigneeWarehouses = consigneeWh != null ? consigneeWh : new List<Warehouse__c>();
        }
        
        // Utility methods to check if data exists
        @AuraEnabled 
        public Boolean getHasSupplyOrder() {
            return this.supplyOrder != null;
        }
        
        @AuraEnabled 
        public Boolean getHasConsignorWarehouses() {
            return this.consignorWarehouses != null && !this.consignorWarehouses.isEmpty();
        }
        
        @AuraEnabled 
        public Boolean getHasConsigneeWarehouses() {
            return this.consigneeWarehouses != null && !this.consigneeWarehouses.isEmpty();
        }
        
        @AuraEnabled 
        public Boolean getHasSOProducts() {
            return this.supplyOrder != null && 
                this.supplyOrder.SO_Products__r != null && 
                !this.supplyOrder.SO_Products__r.isEmpty();
        }
        
        @AuraEnabled 
        public Integer getSOProductCount() {
            if (this.supplyOrder != null && this.supplyOrder.SO_Products__r != null) {
                return this.supplyOrder.SO_Products__r.size();
            }
            return 0;
        }
    }
    
    
    /*Manual Sales Order */
    @AuraEnabled(cacheable=true)
    public static List<Account> getConsigneeDistributor(String Id) {
        
        String rtName = [SELECT Id, RecordType.Name FROM Account WHERE Id = :Id].RecordType.Name;
        
        Set<Id> consigneeDistributorsIds = new Set<Id>();
        
        if (rtName == 'Super Distributor') {
            Set<Id> distributorIds = new Set<Id>();
            
            for (Account dist : [SELECT Id FROM Account WHERE ParentId = :Id]) {
                consigneeDistributorsIds.add(dist.Id);
                distributorIds.add(dist.Id);
            }
            
            for (Account subDist : [SELECT Id FROM Account WHERE ParentId IN :distributorIds]) {
                consigneeDistributorsIds.add(subDist.Id);
            }
        } else if (rtName == 'Distributor') {
            for (Account dist : [SELECT Id FROM Account WHERE ParentId = :Id]) {
                consigneeDistributorsIds.add(dist.Id);
            }
        }
        
        if (consigneeDistributorsIds.isEmpty()) {
            return new List<Account>();
        }
        
        return [SELECT Id, Name FROM Account WHERE Id IN :consigneeDistributorsIds];
    }
    
    @AuraEnabled
    public static String latestSOName(Id accountId) {
        Account acc = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
        String accName = acc.Name;
        
        String[] accParts = accName != null ? accName.split(' ') : new String[0];
        String firstWord = accParts.size() > 0 ? accParts[0] : 'Account';
        
        List<Supply_Order__c> soList = [
            SELECT Name
            FROM Supply_Order__c
            WHERE Name LIKE :('SO-' + firstWord + '-%')
            ORDER BY CreatedDate DESC
        ];
        
        Integer nextNumber = 1;
        
        for (Supply_Order__c so : soList) {
            
            List<String> parts = so.Name.split('-');
            if (parts.size() == 3 && Pattern.matches('\\d+', parts[2])) {
                Integer num = Integer.valueOf(parts[2]);
                if (num >= nextNumber) {
                    nextNumber = num + 1;
                }
            }
        }
        
        String nextNumberStr = String.valueOf(100000 + nextNumber).substring(1);
        return 'SO-' + firstWord + '-' + nextNumberStr;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Zydus_Product__c> getProductByPB(String PBId) {
        if (String.isBlank(PBId)) {
            return new List<Zydus_Product__c>();
        }
        
        return [
            SELECT Id, Name
            FROM Zydus_Product__c
            WHERE Id IN (
                SELECT Zydus_Product__c
                FROM Zydus_Price_Book_Entry__c
                WHERE Zydus_Price_Book__c =: PBId
                AND Is_Active__c = true
            )
        ];
    }
    
    
    
    @AuraEnabled(cacheable=true)
    public static List<Warehouse_Product_Line_Items__c> getWarehouseLineItem(String Id) {
        
        Set<Id> warehouseIds=new Set<Id>();
        
        for(Warehouse__c wh:[SELECT Id, Name FROM Warehouse__c WHERE Account__c =:Id]){
            warehouseIds.add(wh.Id);
        }
        
        return [
            SELECT
            Name,
            Warehouse__r.Zydus_Product__r.Name,
            Warehouse__r.Zydus_Product__c,
            Connected_Warehouse__r.Name,
            Serial_Number__c,
            Batch_Number__c,
            Status__c,
            Condition__c,
            Expiry_Date__c,
            Is_Expired__c,
            Manufactured_Date__c,
            Unit_Price__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Connected_Warehouse__c IN :warehouseIds AND Status__c='Free' AND Condition__c='Good'
        ];
    }
    @AuraEnabled(cacheable=true)
    public static List<Zydus_Product__c> getProductForConsignee(String consigneeId) {
        try {
            if (String.isBlank(consigneeId)) {
                return new List<Zydus_Product__c>();
            }
            
            Account acc = [
                SELECT Zydus_Price_Book__c
                FROM Account
                WHERE Id = :consigneeId
                LIMIT 1
            ];
            
            if (acc.Zydus_Price_Book__c == null) {
                return new List<Zydus_Product__c>();
            }
            
            return [
                SELECT Id
                FROM Zydus_Product__c
                WHERE Id IN (
                    SELECT Zydus_Product__c
                    FROM Zydus_Price_Book_Entry__c
                    WHERE Zydus_Price_Book__c = :acc.Zydus_Price_Book__c
                    AND Is_Active__c = true
                )
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching products: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id createSupplyOrderWithLineItems(
        Id consigneeId,
        Id consignorId,
        String warehouseItemsJson 
    ) {
        // Deserialize JSON
        List<SupplyOrderLineItemDTO> warehouseItems = (List<SupplyOrderLineItemDTO>)
            JSON.deserialize(warehouseItemsJson, List<SupplyOrderLineItemDTO>.class);
        
        System.debug('warehouseItems: ' + warehouseItems);
        
        // Fetch consignee and consignor accounts to get states
        Map<Id, Account> accountsMap = new Map<Id, Account>([
            SELECT Id, State__c FROM Account WHERE Id IN :new Set<Id>{consigneeId, consignorId}
        ]);
        String buyerState = accountsMap.get(consigneeId).State__c;
        String supplierState = accountsMap.get(consignorId).State__c;
        String supplyType = buyerState == supplierState ? 'Intra-State' : 'Inter-State';
        
        // Create Supply Order
        Supply_Order__c so = new Supply_Order__c();
        so.Name = latestSOName(consignorId);
        so.Consignee_Distributor__c = consigneeId;
        so.Consignor_Distributor__c = consignorId;
        so.SO_Generated_Date__c = Date.today();
        so.is_without_PO__c = true;
        insert so;
        
        // Gather required Zydus Products
        Set<String> zydusProductIds = new Set<String>();
        for (SupplyOrderLineItemDTO item : warehouseItems) {
            if (!String.isBlank(item.zydusProductId)) {
                zydusProductIds.add(item.zydusProductId);
            }
        }
        
        // Insert SO Products
        List<SO_Product__c> soProducts = new List<SO_Product__c>();
        for (String zpId : zydusProductIds) {
            soProducts.add(new SO_Product__c(
                Supply_Order__c = so.Id,
                Zydus_Product__c = zpId
            ));
        }
        insert soProducts;
        
        Map<String, SO_Product__c> zydusToSoProductMap = new Map<String, SO_Product__c>();
        for (SO_Product__c sp : soProducts) {
            zydusToSoProductMap.put(sp.Zydus_Product__c, sp);
        }
        
        // Fetch HSN Code for Zydus Products
        Map<Id, Zydus_Product__c> zydusProductMap = new Map<Id, Zydus_Product__c>(
            [SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :zydusProductIds]
        );
        Set<Id> hsnCodeIds = new Set<Id>();
        for (Zydus_Product__c zp : zydusProductMap.values()) {
            if (zp.HSN_Code__c != null) {
                hsnCodeIds.add(zp.HSN_Code__c);
            }
        }
        
        // Fetch HSN tax links
        Date today = Date.today();
        Map<String, HSN_Tax_Master_Link__c> taxRateMap = new Map<String, HSN_Tax_Master_Link__c>();
        for (HSN_Tax_Master_Link__c tax : [
            SELECT Id, HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c,
            Tax_Master__r.State__c
            FROM HSN_Tax_Master_Link__c
            WHERE HSN_Code__c IN :hsnCodeIds
            AND Is_Active__c = TRUE
            AND Tax_Master__r.Is_Active__c = TRUE
            AND Tax_Master__r.Effective_From__c <= :today
            AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :today)
            AND HSN_Code__r.Is_Active__c = TRUE
        ]) {
            String key = tax.HSN_Code__c + '_' + supplierState + '_' + tax.Supply_Type__c;
            taxRateMap.put(key, tax);
        }
        
        // Prepare Line Items
        List<Supply_Order_Line_Item__c> lineItems = new List<Supply_Order_Line_Item__c>();
        for (SupplyOrderLineItemDTO item : warehouseItems) {
            if (String.isBlank(item.zydusProductId)) continue;
            
            SO_Product__c soProduct = zydusToSoProductMap.get(item.zydusProductId);
            if (soProduct == null) {
                throw new AuraHandledException('No SO Product found for Zydus Product Id: ' + item.zydusProductId);
            }
            
            Decimal unitPrice = String.isBlank(item.unitPrice) ? 0 : Decimal.valueOf(item.unitPrice);
            Decimal quantity = 1; // Default to 1 or add quantity field in DTO if available
            Decimal taxableValue = unitPrice * quantity;
            
            // Tax logic
            Zydus_Product__c zp = zydusProductMap.get(item.zydusProductId);
            Decimal cgst = 0, sgst = 0, igst = 0;
            if (zp != null && zp.HSN_Code__c != null) {
                String taxKey = zp.HSN_Code__c + '_' + supplierState + '_' + supplyType;
                HSN_Tax_Master_Link__c tax = taxRateMap.get(taxKey);
                
                if (tax != null) {
                    if (supplyType == 'Intra-State') {
                        cgst = taxableValue * (tax.CGST__c / 100);
                        sgst = taxableValue * (tax.SGST__c / 100);
                    } else {
                        igst = taxableValue * (tax.IGST__c / 100);
                    }
                }
            }
            
            // Build line item
            Supply_Order_Line_Item__c lineItem = new Supply_Order_Line_Item__c();
            lineItem.Supply_Order__c = so.Id;
            lineItem.Name = item.name;
            lineItem.Serial_Number__c = item.serialNumber;
            lineItem.Batch_Number__c = item.batchNumber;
            
            if (!String.isBlank(item.expiryDate)) {
                lineItem.Expiry_Date__c = Date.valueOf(item.expiryDate);
            }
            if (!String.isBlank(item.manufacturedDate)) {
                lineItem.Manufacturing_Date__c = Date.valueOf(item.manufacturedDate);
            }
            
            lineItem.Warehouse_Product_Line_Item__c = item.lineItemId;
            lineItem.Zydus_Product__c = item.zydusProductId;
            lineItem.SO_Product__c = soProduct.Id;
            lineItem.Unit_Price__c = unitPrice;
            lineItem.CGST__c = cgst;
            lineItem.SGST__c = sgst;
            lineItem.IGST__c = igst;
            
            lineItems.add(lineItem);
        }
        
        insert lineItems;
        return so.Id;
    }
    
    public class SupplyOrderLineItemDTO {
        public String name;
        public String warehouseId;
        public String serialNumber;
        public String batchNumber;
        public String manufacturedDate;
        public String expiryDate;
        public String lineItemId;
        public String zydusProductId;
        public String taxMaster;
        public String unitPrice;
    }
    
}