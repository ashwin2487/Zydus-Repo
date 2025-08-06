public without sharing class WarehouseInventoryController {
    
    @AuraEnabled
    public static List<Map<String, Object>> getInventoryData(
        List<Id> warehouseIds,
        String statusFilter
    ) {
        
        Date today = Date.today();
        Date aboutToExpireCutoff = today.addDays(30);
        List<Warehouse_Product_Line_Items__c> items = !String.isEmpty(statusFilter)? [
            SELECT
            Id,
            Connected_Warehouse__r.Name,                
            Warehouse__r.Zydus_Product__r.Name,                   
            Warehouse__r.Zydus_Product__r.Product_Code__c,         
            Warehouse__r.Zydus_Product__r.Brand__r.Name,            
            Warehouse__r.Zydus_Product__r.Size__c,                 
            Warehouse__r.Zydus_Product__r.Quantity_Unit_Of_Measure__c, 
            Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.Zydus_Product__r.MRP__c,
            Batch_Number__c,                        
            Serial_Number__c,                         
            Manufactured_Date__c,                   
            Expiry_Date__c,                           
            Is_Expired__c,
            Unit_Price__c,                            
            Status__c,                                  
            Condition__c,                            
            Sold_Date__c,                               
            Connected_Warehouse__r.Account__r.Name,
            Connected_Warehouse__r.Hospital__r.Name
            FROM Warehouse_Product_Line_Items__c
            WHERE
            Connected_Warehouse__c IN :warehouseIds
            AND Status__c = :statusFilter
        ]: [ SELECT
            Id,
            Connected_Warehouse__r.Name,                
            Warehouse__r.Zydus_Product__r.Name,                   
            Warehouse__r.Zydus_Product__r.Product_Code__c,         
            Warehouse__r.Zydus_Product__r.Brand__r.Name,            
            Warehouse__r.Zydus_Product__r.Size__c,                 
            Warehouse__r.Zydus_Product__r.Quantity_Unit_Of_Measure__c, 
            Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.Zydus_Product__r.MRP__c,
            Batch_Number__c,                        
            Serial_Number__c,                         
            Manufactured_Date__c,                   
            Expiry_Date__c,                           
            Is_Expired__c,
            Unit_Price__c,                            
            Status__c,                                  
            Condition__c,                            
            Sold_Date__c,                               
            Connected_Warehouse__r.Account__r.Name,
            Connected_Warehouse__r.Hospital__r.Name
            FROM Warehouse_Product_Line_Items__c
            WHERE Connected_Warehouse__c IN :warehouseIds];
        
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        
        Map<String, AggregateInfo> aggregateMap = new Map<String, AggregateInfo>();
        
        for (Warehouse_Product_Line_Items__c item : items) {
            String groupKey = String.valueOf(item.Connected_Warehouse__c) + '_' + 
                String.valueOf(item.Warehouse__r.Zydus_Product__c) + '_' +
                String.valueOf(item.Batch_Number__c) + '_' +
                String.valueOf(item.Serial_Number__c);
            
            AggregateInfo aggInfo;
            
            if (aggregateMap.containsKey(groupKey)) {
                aggInfo = aggregateMap.get(groupKey);
            } else {
                aggInfo = new AggregateInfo(
                    item.Connected_Warehouse__r.Name,
                    item.Warehouse__r.Zydus_Product__r.Name,
                    item.Warehouse__r.Zydus_Product__r.Product_Code__c,
                    item.Warehouse__r.Zydus_Product__r.Brand__r.Name,
                    item.Warehouse__r.Zydus_Product__r.Size__c,
                    item.Warehouse__r.Zydus_Product__r.Quantity_Unit_Of_Measure__c,
                    item.Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.Zydus_Product__r.MRP__C,
                    item.Batch_Number__c,
                    item.Serial_Number__c,
                    item.Manufactured_Date__c,
                    item.Connected_Warehouse__r.Account__r.Name ,
                    item.Connected_Warehouse__r.Hospital__r.Name
                );
                aggregateMap.put(groupKey, aggInfo);
            }
            
            Decimal unitPrice = item.Unit_Price__c != null ? item.Unit_Price__c : 0;
            Decimal quantity = 1; 
            
            aggInfo.totalQty += quantity;
            aggInfo.totalValue += (unitPrice * quantity);
            
            if (item.Expiry_Date__c != null) {
                aggInfo.expiryDate = item.Expiry_Date__c;
                aggInfo.balanceExpDays = today.daysBetween(item.Expiry_Date__c);
                
                if (item.Is_Expired__c || item.Expiry_Date__c < today) {
                    aggInfo.expiryCategory = 'Expired';
                    aggInfo.expiredQty += quantity;
                    aggInfo.expiredValue += (unitPrice * quantity);
                } else if (item.Expiry_Date__c <= aboutToExpireCutoff) {
                    aggInfo.expiryCategory = 'About to Expire';
                    aggInfo.usableQty += quantity;
                    aggInfo.usableValue += (unitPrice * quantity);
                } else {
                    aggInfo.expiryCategory = 'Good';
                    aggInfo.usableQty += quantity;
                    aggInfo.usableValue += (unitPrice * quantity);
                }
            } else {
                aggInfo.usableQty += quantity;
                aggInfo.usableValue += (unitPrice * quantity);
                aggInfo.expiryCategory = 'No Expiry';
            }
            
            if (item.Condition__c == 'Damaged' || item.Status__c == 'In Transit') {
                aggInfo.inTransitDamaged++;
            }
            
            if (item.Status__c != 'Available'  && item.Status__c != 'Delivered' ) {
                aggInfo.restricted++;
            }
            
            if (item.Sold_Date__c != null) {
                if (aggInfo.lastUsageDate == null || item.Sold_Date__c > aggInfo.lastUsageDate) {
                    aggInfo.lastUsageDate = item.Sold_Date__c;
                }
            }
            aggInfo.stockStage = determineStockStage(item, today, aboutToExpireCutoff);
        }
        for (AggregateInfo aggInfo : aggregateMap.values()) {
            rows.add(aggInfo.toRowMap());
        }
        
        System.debug('ROWS; '+rows);
        return rows;
    }
    private static String determineStockStage(Warehouse_Product_Line_Items__c item, Date today, Date aboutToExpireCutoff) {
        if (item.Is_Expired__c || (item.Expiry_Date__c != null && item.Expiry_Date__c < today)) {
            return 'Expired';
        } else if (item.Expiry_Date__c != null && item.Expiry_Date__c <= aboutToExpireCutoff) {
            return 'Near Expiry';
        } else if (item.Condition__c == 'Damaged') {
            return 'Damaged';
        } else if (item.Status__c == 'Material Returned') {
            return 'Material Returned';
        } else if (item.Status__c == 'In Transit') {
            return 'In Transit';
        } else {
            return 'Available';
        }
    }
    
    private class AggregateInfo {
        final String warehouseName;
        final String productName;
        final String materialCode;
        final String brand;
        final String size;
        final String uom;
        final Decimal mrp;
        final String batchNumber;
        final String serialNumber;
        final Date manufacturedDate;
        final String distributor;
        final String hospital;
        Decimal totalQty       = 0;
        Decimal totalValue     = 0;
        Decimal expiredQty     = 0;
        Decimal expiredValue   = 0;
        Decimal usableQty      = 0;
        Decimal usableValue    = 0;
        Integer inTransitDamaged = 0;
        Integer restricted      = 0;
        Date    lastUsageDate   = null;
        Date    expiryDate      = null;
        Integer balanceExpDays  = null;
        String  expiryCategory  = null;
        String  stockStage      = null;
        public AggregateInfo(String warehouseName, String productName, String materialCode, 
                             String brand, String size, String uom, Decimal mrp, 
                             String batchNumber, String serialNumber, Date manufacturedDate,
                             String distributor, String hospital) {
                                 this.warehouseName = warehouseName;
                                 this.productName = productName;
                                 this.materialCode = materialCode;
                                 this.brand = brand;
                                 this.size = size;
                                 this.uom = uom;
                                 this.mrp = mrp;
                                 this.batchNumber = batchNumber;
                                 this.serialNumber = serialNumber;
                                 this.manufacturedDate = manufacturedDate;
                                 this.distributor = distributor;
                                 this.hospital = hospital;
                             }
        
        Map<String, Object> toRowMap() {
            return new Map<String, Object>{
                'warehouseName'      => warehouseName,
                    'productName'        => productName,
                    'materialCode'       => materialCode,
                    'brand'              => brand,
                    'size'               => size,
                    'uom'                => uom,
                    'batchNumber'        => batchNumber,
                    'serialNumber'       => serialNumber,
                    'manufacturedDate'   => manufacturedDate,
                    'expiryDate'         => expiryDate,
                    'expiryCategory'     => expiryCategory,
                    'balanceExpDays'     => balanceExpDays,
                    'totalQty'           => totalQty,
                    'totalValueMRP'      => totalValue,
                    'expiredQty'         => expiredQty,
                    'expiredValue'       => expiredValue,
                    'usableQty'          => usableQty,
                    'usableValue'        => usableValue,
                    'inTransitDamaged'   => inTransitDamaged,
                    'restricted'         => restricted,
                    'lastUsageDate'      => lastUsageDate,
                    'stockStage'         => stockStage,
                    'distributor'        => distributor,
                    'hospital'           => hospital
                    };
                        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Warehouse__c> getUserWarehouses(String recordId) {        
        return [
            SELECT Id, Name 
            FROM Warehouse__c 
            WHERE Account__c =:recordId OR  hospital__c =:recordId
        ];
    }
    
    @AuraEnabled
    public static List<Map<String, Object>> getInventoryDataForInTransit(List<Id> warehouseId) {
        Set<String> serialNumbers=new Set<String>();
        
        Id accId=[SELECT Id, Account__c FROM Warehouse__c WHERE Id IN:warehouseId LIMIT 1].Account__c;
        
        for(Delivery_Challan_Line_Item__c dcli: [SELECT Id, Serial_Number__c FROM Delivery_Challan_Line_Item__c WHERE Delivery_Challan__r.Consignee_Distributor__c=:accId]){
            serialNumbers.add(dcli.Serial_Number__c);
        }
        
        Date today = Date.today();
        Date aboutToExpireCutoff = today.addDays(30);
        
        List<Warehouse_Product_Line_Items__c> items = [
            SELECT
            Id,
            Connected_Warehouse__r.Name,                
            Warehouse__r.Zydus_Product__r.Name,                   
            Warehouse__r.Zydus_Product__r.Product_Code__c,         
            Warehouse__r.Zydus_Product__r.Brand__r.Name,            
            Warehouse__r.Zydus_Product__r.Size__c,                 
            Warehouse__r.Zydus_Product__r.Quantity_Unit_Of_Measure__c, 
            Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.Zydus_Product__r.MRP__c,
            Batch_Number__c,                        
            Serial_Number__c,                         
            Manufactured_Date__c,                   
            Expiry_Date__c,                           
            Is_Expired__c,
            Unit_Price__c,                            
            Status__c,                                  
            Condition__c,                            
            Sold_Date__c,                               
            Connected_Warehouse__r.Account__r.Name,
            Connected_Warehouse__r.Hospital__r.Name
            FROM Warehouse_Product_Line_Items__c
            WHERE Serial_Number__c IN :serialNumbers
            AND Status__c='In Transit'
            
        ];
        
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        
        Map<String, AggregateInfo> aggregateMap = new Map<String, AggregateInfo>();
        
        for (Warehouse_Product_Line_Items__c item : items) {
            String groupKey = String.valueOf(item.Connected_Warehouse__c) + '_' + 
                String.valueOf(item.Warehouse__r.Zydus_Product__c) + '_' +
                String.valueOf(item.Batch_Number__c) + '_' +
                String.valueOf(item.Serial_Number__c);
            
            AggregateInfo aggInfo;
            
            if (aggregateMap.containsKey(groupKey)) {
                aggInfo = aggregateMap.get(groupKey);
            } else {
                aggInfo = new AggregateInfo(
                    item.Connected_Warehouse__r.Name,
                    item.Warehouse__r.Zydus_Product__r.Name,
                    item.Warehouse__r.Zydus_Product__r.Product_Code__c,
                    item.Warehouse__r.Zydus_Product__r.Brand__r.Name,
                    item.Warehouse__r.Zydus_Product__r.Size__c,
                    item.Warehouse__r.Zydus_Product__r.Quantity_Unit_Of_Measure__c,
                    item.Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.Zydus_Product__r.MRP__C,
                    item.Batch_Number__c,
                    item.Serial_Number__c,
                    item.Manufactured_Date__c,
                    item.Connected_Warehouse__r.Account__r.Name ,
                    item.Connected_Warehouse__r.Hospital__r.Name
                );
                aggregateMap.put(groupKey, aggInfo);
            }
            
            Decimal unitPrice = item.Unit_Price__c != null ? item.Unit_Price__c : 0;
            Decimal quantity = 1; 
            
            aggInfo.totalQty += quantity;
            aggInfo.totalValue += (unitPrice * quantity);
            
            if (item.Expiry_Date__c != null) {
                aggInfo.expiryDate = item.Expiry_Date__c;
                aggInfo.balanceExpDays = today.daysBetween(item.Expiry_Date__c);
                
                if (item.Is_Expired__c || item.Expiry_Date__c < today) {
                    aggInfo.expiryCategory = 'Expired';
                    aggInfo.expiredQty += quantity;
                    aggInfo.expiredValue += (unitPrice * quantity);
                } else if (item.Expiry_Date__c <= aboutToExpireCutoff) {
                    aggInfo.expiryCategory = 'About to Expire';
                    aggInfo.usableQty += quantity;
                    aggInfo.usableValue += (unitPrice * quantity);
                } else {
                    aggInfo.expiryCategory = 'Good';
                    aggInfo.usableQty += quantity;
                    aggInfo.usableValue += (unitPrice * quantity);
                }
            } else {
                aggInfo.usableQty += quantity;
                aggInfo.usableValue += (unitPrice * quantity);
                aggInfo.expiryCategory = 'No Expiry';
            }
            
            if (item.Condition__c == 'Damaged' || item.Status__c == 'In Transit') {
                aggInfo.inTransitDamaged++;
            }
            
            if (item.Status__c != 'Available'  && item.Status__c != 'Delivered' ) {
                aggInfo.restricted++;
            }
            
            if (item.Sold_Date__c != null) {
                if (aggInfo.lastUsageDate == null || item.Sold_Date__c > aggInfo.lastUsageDate) {
                    aggInfo.lastUsageDate = item.Sold_Date__c;
                }
            }
            aggInfo.stockStage = determineStockStage(item, today, aboutToExpireCutoff);
        }
        for (AggregateInfo aggInfo : aggregateMap.values()) {
            rows.add(aggInfo.toRowMap());
        }
        
        System.debug('ROWS; '+rows);
        return rows;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Warehouse__c> getWarehousesOptions(){
        
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
        
        if(rtName == 'Zydus'){
            return [SELECT Id, Name FROM Warehouse__c ];
        }
        
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
        
        Set<Id> hospIds=new Set<Id>();
        List<Account_Hospital__c> AccHosp=[SELECT Id, Hospital__c FROM Account_Hospital__c WHERE Account__c IN :relatedAccountIds];
        
        for(Account_Hospital__c ah:AccHosp){
            hospIds.add(ah.Hospital__c);
        }
        
        return [
            SELECT Id, Name 
            FROM Warehouse__c 
            WHERE Account__c IN :relatedAccountIds  OR Hospital__c IN :hospIds
        ];
        
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Warehouse_Product_Line_Items__c> getWPLIs(Id warehouseId) {
        if (warehouseId == null) {
            return new List<Warehouse_Product_Line_Items__c>();
        }
        
        try {
            Warehouse__c warehouse = [SELECT RecordType.Name FROM Warehouse__c WHERE Id = :warehouseId LIMIT 1];
            
            String query = 'SELECT Id, Name, Connected_Warehouse__r.Name, Warehouse__r.Zydus_Product__r.Name, ' +
                'Serial_Number__c, Batch_Number__c, Expiry_Date__c, Status__c, Condition__c, RSO_Created__c ' +
                'FROM Warehouse_Product_Line_Items__c ' +
                'WHERE Connected_Warehouse__c = :warehouseId AND RSO_Created__c = false AND Status__c = \'Available\' ';
            
            if (warehouse.RecordType.Name == 'Hospital') {
                Id currentUserId = UserInfo.getUserId();
                query += ' AND Delivery_Challan_Line_Item__r.Delivery_Challan__r.OwnerId = :currentUserId';
            }
            
            return Database.query(query);
            
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred while retrieving items: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id createReverseSupplyOrders(List<Id> selectedWpliIds) {
        List<Id> insertedAccountShareIds = new List<Id>();
        List<Id> insertedWarehouseShareIds = new List<Id>();
        
        if (selectedWpliIds == null || selectedWpliIds.isEmpty()) {
            System.debug('No WPLI IDs provided. Exiting.');
            return null;
        }
        Set<Id> accountIdsToShare = new Set<Id>();
        Id currUserId = UserInfo.getUserId();
        List<Warehouse_Product_Line_Items__c> wplis = [
            SELECT
            Id, Name, Batch_Number__c, Serial_Number__c, Expiry_Date__c, Manufactured_Date__c,
            Warehouse__r.Zydus_Product__c, Warehouse__r.Zydus_Product__r.HSN_Code__c, Connected_Warehouse__c,
            Supply_Order_Line_Item__r.Unit_Price__c,
            GRN__r.Delivery_Challan__r.Supply_Order__c,
            GRN__r.Delivery_Challan__r.Supply_Order__r.Name,
            GRN__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__c,
            GRN__r.Delivery_Challan__r.Supply_Order__r.Consignor_Distributor__c,
            GRN__r.Delivery_Challan__r.Supply_Order__r.Consignee_Distributor__c,
            GRN__r.Delivery_Challan__r.Consignee_Distributor__c,
            GRN__r.Delivery_Challan__r.Consignee_Hospital__c,
            GRN__r.Delivery_Challan__r.Consignor_Distributor__c,
            GRN__r.Delivery_Challan__r.RecordType.DeveloperName
            FROM Warehouse_Product_Line_Items__c
            WHERE Id IN : selectedWpliIds
        ];
        
        Map<String, List<Warehouse_Product_Line_Items__c>> groupedWplis = new Map<String, List<Warehouse_Product_Line_Items__c>>();
        Set<Id> hsnIds = new Set<Id>();
        Set<Id> consigneeDistributorIds = new Set<Id>();
        Set<Id> consigneeHospitalIds = new Set<Id>();
        Set<Id> consignorDistributorIds = new Set<Id>();
        
        for (Warehouse_Product_Line_Items__c wpli : wplis) {
            String groupKey;
            
            if (wpli.GRN__r?.Delivery_Challan__c != null) {
                groupKey = 'DC_' + wpli.GRN__r.Delivery_Challan__c;
                
                if (wpli.GRN__r?.Delivery_Challan__r?.Consignee_Hospital__c != null) {
                    consigneeHospitalIds.add(wpli.GRN__r.Delivery_Challan__r.Consignee_Hospital__c);
                }
                if (wpli.GRN__r?.Delivery_Challan__r?.Consignee_Distributor__c != null) {
                    consigneeDistributorIds.add(wpli.GRN__r.Delivery_Challan__r.Consignee_Distributor__c);
                    accountIdsToShare.add(wpli.GRN__r.Delivery_Challan__r.Consignee_Distributor__c);
                }
                if (wpli.GRN__r?.Delivery_Challan__r?.Consignor_Distributor__c != null) {
                    consignorDistributorIds.add(wpli.GRN__r.Delivery_Challan__r.Consignor_Distributor__c);
                    accountIdsToShare.add(wpli.GRN__r.Delivery_Challan__r.Consignor_Distributor__c);
                }
            }
            
            
            if (groupKey != null) {
                if (!groupedWplis.containsKey(groupKey)) {
                    groupedWplis.put(groupKey, new List<Warehouse_Product_Line_Items__c>());
                }
                groupedWplis.get(groupKey).add(wpli);
                
                if (wpli.Warehouse__r?.Zydus_Product__r?.HSN_Code__c != null) {
                    hsnIds.add(wpli.Warehouse__r.Zydus_Product__r.HSN_Code__c);
                }
            }
        }
        /*// share parent account
        List<AccountShare> sharesToInsert = new List<AccountShare>();
        for (Id accId : accountIdsToShare) {
            AccountShare accShare = new AccountShare();
            accShare.AccountId = accId;
            accShare.UserOrGroupId = currUserId;
            accShare.AccountAccessLevel = 'Edit';
            accShare.OpportunityAccessLevel = 'None';
            accShare.CaseAccessLevel = 'None';
            accShare.RowCause = Schema.AccountShare.RowCause.Manual;
            sharesToInsert.add(accShare);
        }
        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
            for (AccountShare share : sharesToInsert) {
                insertedAccountShareIds.add(share.Id);
            }
        }
        
        // --- Warehouse__Share ---
        List<Warehouse__Share> warehouseSharesToInsert = new List<Warehouse__Share>();
        List<Warehouse__c> warehousesToShare = [
            SELECT Id, Account__c
            FROM Warehouse__c
            WHERE Account__c IN :accountIdsToShare
        ];
        
        for (Warehouse__c warehouse : warehousesToShare) {
            Warehouse__Share wShare = new Warehouse__Share();
            wShare.ParentId = warehouse.Id;
            wShare.UserOrGroupId = currUserId;
            wShare.AccessLevel = 'Edit';
            wShare.RowCause = Schema.Warehouse__Share.RowCause.Manual;
            warehouseSharesToInsert.add(wShare);
        }
        
        Database.SaveResult[] warehouseInsertResults = Database.insert(warehouseSharesToInsert, false);
        
        for (Integer i = 0; i < warehouseInsertResults.size(); i++) {
            if (warehouseInsertResults[i].isSuccess()) {
                insertedWarehouseShareIds.add(warehouseSharesToInsert[i].Id);
            } else {
                System.debug('Failed to insert Warehouse__Share: ' + warehouseInsertResults[i].getErrors()[0].getMessage());
            }
        }*/
        if (groupedWplis.isEmpty()) {
            return null;
        }
        
        Map<Id, Account> consigneeDistributorMap = new Map<Id, Account>();
        for (Id distributorId : consigneeDistributorIds) {
            Account parentAccount = AccountAccessUtil.getParentBusinessOwner(distributorId);
            consigneeDistributorMap.put(distributorId, parentAccount);
        }
        
        Map<Id, Account> consignorDistributorMap = new Map<Id, Account>();
        for (Id distributorId : consignorDistributorIds) {
            Account parentAccount = AccountAccessUtil.getParentBusinessOwner(distributorId);
            consignorDistributorMap.put(distributorId, parentAccount);
        }
        system.debug('consigneeHospitalIds'+consigneeHospitalIds);
        Map<Id, Hospital__c> hospitalMap = new Map<Id, Hospital__c>();
        if (!consigneeHospitalIds.isEmpty()) {
            hospitalMap = new Map<Id, Hospital__c>([SELECT Id, Name, State__c FROM Hospital__c WHERE Id IN :consigneeHospitalIds]);
        }
        
        Id rsoRT = getRecordTypeId('Supply_Order__c', 'RSO');
        List<Supply_Order__c> newSOsToInsert = new List<Supply_Order__c>();
        
        for (String groupKey : groupedWplis.keySet()) {
            Warehouse_Product_Line_Items__c sample = groupedWplis.get(groupKey)[0];
            Supply_Order__c rso = new Supply_Order__c();
            
            rso.RecordTypeId = rsoRT;
            rso.SO_Generated_Date__c = Date.today();
            rso.Delivery_Challan__c = sample.GRN__r.Delivery_Challan__c;
            
            // Handle for hospital or distributor
            if (sample.GRN__r.Delivery_Challan__r.Consignee_Hospital__c != null) {
                Id consignorId = sample.GRN__r.Delivery_Challan__r.Consignee_Hospital__c;
                Id consigneeId = sample.GRN__r.Delivery_Challan__r.Consignor_Distributor__c;
                Account consignorDistributor = consignorDistributorMap.get(consigneeId);
                
                rso.Name = latestSOName(consignorDistributor.Id);
                rso.Consignor_Hospital__c = consignorId;
                rso.Consignee_Distributor__c = consigneeId;
                rso.OwnerId = currUserId;
                
            } else {
                // Distributor scenario
                Id consignorId = sample.GRN__r.Delivery_Challan__r.Consignee_Distributor__c;
                Id consigneeId = sample.GRN__r.Delivery_Challan__r.Consignor_Distributor__c;
                Account consigneeDistributor = consignorDistributorMap.get(consigneeId);
                
                if (consigneeDistributor != null) {
                    rso.Name = latestSOName(consigneeDistributor.Id);
                    rso.Consignee_Distributor__c = consigneeDistributor.Id;
                    rso.Consignor_Distributor__c = sample.GRN__r.Delivery_Challan__r.Supply_Order__r.Consignee_Distributor__c;
                    rso.Supply_Order__c = sample.GRN__r.Delivery_Challan__r.Supply_Order__c;
                    rso.New_Purchase_Order__c = sample.GRN__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__c;
                    rso.OwnerId = currUserId;
                } else {
                    System.debug('Null consigneeDistributor for Id: ' + consigneeId);
                    continue;
                }
            }
            
            newSOsToInsert.add(rso);
        }
        
        insert newSOsToInsert;
        
        
        List<Supply_Order__c> newSOs = [
            SELECT Id, Name, Supply_Order__c, Delivery_Challan__c, Consignee_Distributor__c, Consignor_Distributor__c,Consignor_Hospital__c 
            FROM Supply_Order__c
            WHERE Id IN :newSOsToInsert
        ];
        
        List<SO_Product__c> soProductsToInsert = new List<SO_Product__c>();
        Set<String> soProductKeys = new Set<String>();
        for (Supply_Order__c rso : newSOs) {
             String lookupKey = 'DC_' + rso.Delivery_Challan__c;
            List<Warehouse_Product_Line_Items__c> relatedWplis = groupedWplis.get(lookupKey);
            if (relatedWplis != null){
                for (Warehouse_Product_Line_Items__c wpli : relatedWplis) {
                    Id productId = wpli.Warehouse__r.Zydus_Product__c;
                    String key = rso.Id + '-' + productId;
                    if (!soProductKeys.contains(key)) {
                        soProductsToInsert.add(new SO_Product__c(
                            Zydus_Product__c = productId,
                            Supply_Order__c = rso.Id
                        ));
                        soProductKeys.add(key);
                    }
                }
            }
            insert soProductsToInsert;
        }
        
        
        Map<String, Id> productKeyToSoProductId = new Map<String, Id>();
        for (SO_Product__c sop : soProductsToInsert) {
            productKeyToSoProductId.put(sop.Supply_Order__c + '-' + sop.Zydus_Product__c, sop.Id);
        }
        
        List<Supply_Order_Line_Item__c> soLineItemsToInsert = new List<Supply_Order_Line_Item__c>();
        
        final String ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        Map<Id, Integer> productToSopNumber = new Map<Id, Integer>();
        Map<Id, Integer> productToSuffix   = new Map<Id, Integer>();
        Id priceBookId;
        String supplyType;
        String supplierState;
        String buyerState;
        
        List<Warehouse_Product_Line_Items__c> relatedWplis = new list<Warehouse_Product_Line_Items__c>();
        for (Supply_Order__c rso : newSOs) {
            if(rso.Consignee_Distributor__c!= null && rso.Consignor_Distributor__c != null && rso.Consignor_Hospital__c == null){
                String lookupKey = 'DC_' + rso.Delivery_Challan__c;

                relatedWplis = groupedWplis.get(lookupKey);
                
                buyerState = [SELECT State__c FROM Account WHERE Id = :rso.Consignee_Distributor__c].State__c;
                supplierState = [SELECT State__c FROM Account WHERE Id = :rso.Consignor_Distributor__c].State__c;
                
                supplyType = (buyerState != null && buyerState == supplierState) ? 'Intra-State' : 'Inter-State';
                
                priceBookId = [SELECT Zydus_Price_Book__c FROM Account WHERE Id = :rso.Consignor_Distributor__c].Zydus_Price_Book__c;
            }else if(rso.Consignee_Distributor__c!= null && rso.Consignor_Distributor__c == null && rso.Consignor_Hospital__c != null){
                String lookupKey = 'DC_' + rso.Delivery_Challan__c;
                relatedWplis = groupedWplis.get(lookupKey);
                
                buyerState = [SELECT State__c FROM Account WHERE Id = :rso.Consignee_Distributor__c].State__c;
                supplierState = [SELECT State__c FROM Hospital__c WHERE Id = :rso.Consignor_Hospital__c].State__c;
                
                supplyType = (buyerState != null && buyerState == supplierState) ? 'Intra-State' : 'Inter-State';
                
                priceBookId = [SELECT Zydus_Price_Book__c FROM Hospital__c WHERE Id = :rso.Consignor_Hospital__c].Zydus_Price_Book__c;
            }
            
            
            Map<Id, Id> zydusPbeMap = new Map<Id, Id>();
            if (priceBookId != null) {
                for (Zydus_Price_Book_Entry__c pbe :
                     [SELECT Id, Zydus_Product__c FROM Zydus_Price_Book_Entry__c WHERE Zydus_Price_Book__c = :priceBookId]) {
                         zydusPbeMap.put(pbe.Zydus_Product__c, pbe.Id);
                     }
            }
            Map<Id, Zydus_Price_Book_Entry__c> priceBookEntryMap = new Map<Id, Zydus_Price_Book_Entry__c>(
                [SELECT Id, Unit_Price__c FROM Zydus_Price_Book_Entry__c WHERE Id IN :zydusPbeMap.values()]
            );
            
            Map<String, HSN_Tax_Master_Link__c> taxMap = new Map<String, HSN_Tax_Master_Link__c>();
            if (!hsnIds.isEmpty()) {
                for (HSN_Tax_Master_Link__c tax :
                     [SELECT HSN_Code__c, CGST__c, SGST__c, IGST__c
                      FROM HSN_Tax_Master_Link__c
                      WHERE HSN_Code__c IN :hsnIds
                      AND Supply_Type__c = :supplyType
                      AND Tax_Master__r.Is_Active__c = TRUE
                      AND Tax_Master__r.Effective_From__c <= :Date.today()
                      AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :Date.today())
                     ]) {
                         taxMap.put(tax.HSN_Code__c, tax);
                     }
            }
            
            String orderNumber = rso.Name.replace('RSO-', '');
            Integer productCounter = 1;
            if (relatedWplis != null){
                for (Warehouse_Product_Line_Items__c wpli : relatedWplis) {
                    Id productId = wpli.Warehouse__r.Zydus_Product__c;
                    
                    if (!productToSopNumber.containsKey(productId)) {
                        productToSopNumber.put(productId, productCounter);
                        productCounter++;
                    }
                    Integer sopNumber = productToSopNumber.get(productId);
                    
                    Integer suffixIndex = productToSuffix.containsKey(productId)
                        ? productToSuffix.get(productId)
                        : 1;
                    String baseSuffix = '';
                    Integer temp = suffixIndex;
                    while (temp > 0) {
                        Integer rem = Math.mod(temp - 1, 26);
                        baseSuffix = ALPHA.substring(rem, rem + 1) + baseSuffix;
                        temp = (temp - 1) / 26;
                    }
                    productToSuffix.put(productId, suffixIndex + 1);
                    
                    Decimal unitPrice = 0;
                    Id pbeId = zydusPbeMap.get(productId);
                    if (pbeId != null) {
                        Zydus_Price_Book_Entry__c entry = priceBookEntryMap.get(pbeId);
                        if (entry != null && entry.Unit_Price__c != null) {
                            unitPrice = entry.Unit_Price__c;
                        }
                    }
                    
                    Decimal cgstAmount = 0, sgstAmount = 0, igstAmount = 0;
                    Id hsnCodeId = wpli.Warehouse__r?.Zydus_Product__r?.HSN_Code__c;
                    if (hsnCodeId != null && taxMap.containsKey(hsnCodeId)) {
                        HSN_Tax_Master_Link__c tax = taxMap.get(hsnCodeId);
                        if (supplyType == 'Intra-State') {
                            cgstAmount = (unitPrice * tax.CGST__c) / 100;
                            sgstAmount = (unitPrice * tax.SGST__c) / 100;
                        } else {
                            igstAmount = (unitPrice * tax.IGST__c) / 100;
                        }
                    }
                    Decimal netAmount = unitPrice + cgstAmount + sgstAmount + igstAmount;
                    
                    String soliName = 'RSOP' + sopNumber + '/' + orderNumber + '/' + baseSuffix;
                    Supply_Order_Line_Item__c soli = new Supply_Order_Line_Item__c(
                        Name = soliName,
                        Supply_Order__c = rso.Id,
                        Zydus_Product__c = productId,
                        Unit_Price__c = unitPrice,
                        Warehouse__c = wpli.Connected_Warehouse__c,
                        HSN_Code__c = wpli.Warehouse__r.Zydus_Product__r.HSN_Code__c,
                        CGST__c = cgstAmount,
                        SGST__c = sgstAmount,
                        IGST__c = igstAmount,
                        Net_Amount__c = netAmount,
                        SO_Product__c = productKeyToSoProductId.get(rso.Id + '-' + productId),
                        Serial_Number__c = wpli.Serial_Number__c,
                        Batch_Number__c = wpli.Batch_Number__c,
                        Expiry_Date__c = wpli.Expiry_Date__c,
                        Manufacturing_Date__c = wpli.Manufactured_Date__c,
                        Warehouse_Product_Line_Item__c = wpli.Id,
                        Zydus_Price_Book_Entry__c = pbeId
                    );
                    soLineItemsToInsert.add(soli);
                }
            }
        }
        
        Map<String,Id> serailNumberSOLID = new Map<String,Id>();
        if (!soLineItemsToInsert.isEmpty()) {
            insert soLineItemsToInsert;
        }
        for(Supply_Order_Line_Item__c cur : soLineItemsToInsert){
            serailNumberSOLID.Put(cur.Serial_Number__c,cur.Id);
        }
        for (Warehouse_Product_Line_Items__c wpli : wplis) {
            if(serailNumberSOLID.containsKey(wpli.Serial_Number__c)){
                wpli.RSO_Created__c = true;
                wpli.Status__c = 'Material Returned';
                wpli.Supply_Order_Line_Item__c = serailNumberSOLID.get(wpli.Serial_Number__c);
                wpli.isMaterialReturned__c = true;
            }
            
        }
        update wplis;
        
        List<Supply_Order__c> newSOsWithRelations = [
            SELECT Id, Name, Consignor_Distributor__r.Business_Owner__c, Consignee_Distributor__r.Business_Owner__c 
            FROM Supply_Order__c 
            WHERE Id IN :newSOsToInsert
        ];
        
        for (Supply_Order__c rso : newSOsWithRelations) {
            NotificationService.notifyUsers(
                new Set<String>{
                    rso.Consignor_Distributor__r.Business_Owner__c,
                        rso.Consignee_Distributor__r.Business_Owner__c
                        },
                rso.Id,
                'New RSO Created',
                'An RSO "' + rso.Name + '" has been created. Please review and take appropriate action.'
            );
        }
        try {
            if (!insertedAccountShareIds.isEmpty()) {
                delete [SELECT Id FROM AccountShare WHERE Id IN :insertedAccountShareIds];
            }
            if (!insertedWarehouseShareIds.isEmpty()) {
                delete [SELECT Id FROM Warehouse__Share WHERE Id IN :insertedWarehouseShareIds];
            }
        } catch (Exception e) {
            System.debug('Error cleaning up share records: ' + e.getMessage());
        }
        
        
        return newSOsToInsert[0].Id;
    }
    
    public static Id getRecordTypeId(String objectName, String developerName) {
        RecordType rt = [
            SELECT Id 
            FROM RecordType 
            WHERE SObjectType = :objectName AND DeveloperName = :developerName 
            LIMIT 1
        ];
        return rt.Id;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Warehouse__c> getWarehouses(String recordId) {
        return [SELECT Id FROM Warehouse__c WHERE Account__c = :recordId OR Hospital__c=:recordId];
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
            WHERE Name LIKE :('RSO-' + firstWord + '-%')
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
        return 'RSO-' + firstWord + '-' + nextNumberStr;
    }
    
    @AuraEnabled
    public static Boolean shouldRSObtnVisible(String warehouseId) {
        Id currUserId = UserInfo.getUserId();
        
        if (String.isBlank(warehouseId)) {
            return false;
        }
        Warehouse__c warehouse = [
            SELECT Account__r.Business_Owner__c, RecordType.Name, Hospital__c
            FROM Warehouse__c
            WHERE Id = :warehouseId
            LIMIT 1
        ];
        
        if (warehouse.RecordType.Name !='Hospital' && warehouse.Account__r != null && warehouse.Account__r.Business_Owner__c == currUserId) {
            return true;
        }
        
        if(warehouse.RecordType.Name=='Hospital' && warehouse.Hospital__c !=null){
            List<Account_Hospital__c> ahList=[SELECT Account__r.Business_Owner__c, Hospital__c FROM Account_Hospital__c 
                                              WHERE Hospital__c =:warehouse.Hospital__c AND Account__r.Business_Owner__c = :currUserId];
            
            return !ahList.isEmpty();
        }
        return false;
    }
    
    @AuraEnabled
    public static List<String> getSerialOrProductNumber(String keyword) {
        String escapedKeyword = String.escapeSingleQuotes(keyword);
        String safeKeyword = '%' + escapedKeyword + '%';
        
        Set<String> result = new Set<String>();
        
        List<Warehouse_Product_Line_Items__c> serials = [
            SELECT Serial_Number__c 
            FROM Warehouse_Product_Line_Items__c 
            WHERE Serial_Number__c LIKE :safeKeyword
        ];
        for (Warehouse_Product_Line_Items__c wpli : serials) {
            result.add(wpli.Serial_Number__c);
        }
        
        List<Zydus_Product__c> products = [
            SELECT SAP_Code__c 
            FROM Zydus_Product__c 
            WHERE SAP_Code__c LIKE :safeKeyword
        ];
        for (Zydus_Product__c zp : products) {
            result.add(zp.SAP_Code__c);
        }
        return new List<String>(result);
    }

    
     public class HistoryWrapper {
        @AuraEnabled
        public Warehouse_Product_Line_Items__History historyRecord { get; set; }

        @AuraEnabled
        public String warehouseName { get; set; }
         
        @AuraEnabled
        public String warehouseAccoutRecordType { get; set;}
         
        @AuraEnabled
        public String warehouseId { get; set; }
         
        @AuraEnabled
        public String poName { get; set; }
         
        @AuraEnabled
        public String soName { get; set; }
         
        @AuraEnabled
        public String dcName { get; set; }
    }

    @AuraEnabled
    public static List<HistoryWrapper> getMaterialHistoryByCode(String code) {
        Map<Id, Warehouse_Product_Line_Items__c> parentItemsMap = new Map<Id, Warehouse_Product_Line_Items__c>([
            SELECT Id, Connected_Warehouse__r.Name, Connected_Warehouse__r.Account__r.RecordType.Name, 
            Delivery_Challan_Line_Item__r.Delivery_Challan__r.Name, Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.Name,
            Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__r.Name
            FROM Warehouse_Product_Line_Items__c
            WHERE Serial_Number__c = :code
            OR Warehouse__r.Zydus_Product__r.SAP_Code__c = :code
        ]);

        if (parentItemsMap.isEmpty()) {
            return new List<HistoryWrapper>();
        }

        List<Warehouse_Product_Line_Items__History> historyList = [
            SELECT ParentId, Field, OldValue, NewValue, CreatedById, CreatedBy.Name, CreatedDate
            FROM Warehouse_Product_Line_Items__History
            WHERE ParentId IN :parentItemsMap.keySet()
            ORDER BY CreatedDate DESC
        ];

        List<HistoryWrapper> results = new List<HistoryWrapper>();
        for (Warehouse_Product_Line_Items__History hist : historyList) {
            HistoryWrapper wrap = new HistoryWrapper();
            wrap.historyRecord = hist;
            wrap.warehouseName = parentItemsMap.get(hist.ParentId)?.Connected_Warehouse__r.Name;
            wrap.warehouseId = parentItemsMap.get(hist.ParentId)?.Connected_Warehouse__c;
            wrap.warehouseAccoutRecordType = parentItemsMap.get(hist.ParentId)?.Connected_Warehouse__r.Account__r.RecordType.Name;
            wrap.poName = parentItemsMap.get(hist.ParentId)?.Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__r.Name;
            wrap.soName = parentItemsMap.get(hist.ParentId)?.Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.Name;
            wrap.dcName = parentItemsMap.get(hist.ParentId)?.Delivery_Challan_Line_Item__r.Delivery_Challan__r.Name;
            results.add(wrap);
        }
        return results;
    }
}