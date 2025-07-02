public without sharing class WarehouseInventoryController {
    
    @AuraEnabled
    public static List<Map<String, Object>> getInventoryData(
        List<Id> warehouseIds,
        String statusFilter
    ) {
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
            Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.List_Price__c,
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
        ];
        
        System.debug('items:'+items);
        
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
                    item.Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.List_Price__c,
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
            
            if (item.Status__c != 'Free'  && item.Status__c != 'Delivered' ) {
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
        } else if (item.Status__c == 'Restricted') {
            return 'Restricted';
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
        
        Set<Id> hospWH=new Set<Id>();
        List<Account_Hospital__c> AccHosp=[SELECT Id, Hospital__c, Hospital__r.Warehouse__c FROM Account_Hospital__c WHERE Account__c IN :relatedAccountIds];
        
        for(Account_Hospital__c ah:AccHosp){
            hospWH.add(ah.Hospital__r.Warehouse__c);
        }
        
        return [
            SELECT Id, Name 
            FROM Warehouse__c 
            WHERE Account__c IN :relatedAccountIds  OR  Id IN :hospWH
        ];
        
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Warehouse_Product_Line_Items__c> getWPLIs(Id warehouseId) {
        List<Warehouse_Product_Line_Items__c> wpliList = [
            SELECT Id, Name, Connected_Warehouse__r.Name, Warehouse__r.Zydus_Product__r.Name, Serial_Number__c, Batch_Number__c, Expiry_Date__c, Condition__c, RSO_Created__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Connected_Warehouse__c = :warehouseId
            AND Status__c='Free'
            AND RSO_Created__c = false
        ];
        System.debug('WPLIs for warehouse ' + warehouseId + ': ' + wpliList);
        return wpliList;
    }
    
    
    @AuraEnabled
    public static void createReverseSupplyOrders(List<Id> selectedWpliIds) {
        System.debug('### INPUT selectedWpliIds: ' + selectedWpliIds);
        
        if (selectedWpliIds == null || selectedWpliIds.isEmpty()) {
            System.debug('### EXIT: selectedWpliIds is null or empty.');
            return;
        }
        
        List<Warehouse_Product_Line_Items__c> wplis = [
            SELECT Id, 
            Name,
            Batch_Number__c,
            Serial_Number__c,
            Expiry_Date__c,
            Manufactured_Date__c,
            RSO_Created__c,
            Warehouse__r.Zydus_Product__c,
            Supply_Order_Line_Item__r.CGST__c,
            Supply_Order_Line_Item__r.IGST__c,
            Supply_Order_Line_Item__r.SGST__c,
            Supply_Order_Line_Item__r.Net_Amount__c,
            Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__c,
            Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.List_Price__c,
            GRN__r.Delivery_Challan__r.Supply_Order__c,
            GRN__r.Delivery_Challan__r.Supply_Order__r.Name,
            GRN__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__c,
            GRN__r.Delivery_Challan__r.Supply_Order__r.Consignee_Distributor__c,
            GRN__r.Delivery_Challan__r.Supply_Order__r.Consignor_Distributor__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Id IN :selectedWpliIds
        ];
        
        Map<Id, List<Warehouse_Product_Line_Items__c>> soToWplis = new Map<Id, List<Warehouse_Product_Line_Items__c>>();
        
        for (Warehouse_Product_Line_Items__c wpli : wplis) {
            Id soId = wpli.GRN__r?.Delivery_Challan__r?.Supply_Order__c;
            
            if (soId != null) {
                if (!soToWplis.containsKey(soId)) {
                    soToWplis.put(soId, new List<Warehouse_Product_Line_Items__c>());
                }
                soToWplis.get(soId).add(wpli);
            }
        }
        
        Id rsoRT = getRecordTypeId('Supply_Order__c', 'RSO');
        
        List<Supply_Order__c> newSOs = new List<Supply_Order__c>();
        
        Map<Id, Supply_Order__c> originalToReverseSO = new Map<Id, Supply_Order__c>();
        for (Id originalSoId : soToWplis.keySet()) {
            Warehouse_Product_Line_Items__c sample = soToWplis.get(originalSoId)[0];
            
            Supply_Order__c rso = new Supply_Order__c(
                RecordTypeId = rsoRT,
                Consignee_Distributor__c = sample.GRN__r.Delivery_Challan__r.Supply_Order__r.Consignor_Distributor__c,
                Consignor_Distributor__c = sample.GRN__r.Delivery_Challan__r.Supply_Order__r.Consignee_Distributor__c,
                Supply_Order__c = originalSoId,
                New_Purchase_Order__c = sample.GRN__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__c,
                SO_Generated_Date__c = Date.today()
            );
            
            newSOs.add(rso);
            originalToReverseSO.put(originalSoId, rso);
        }
        
        insert newSOs;
        
        Map<String, SO_Product__c> soProductKeyMap = new Map<String, SO_Product__c>();
        List<SO_Product__c> soProducts = new List<SO_Product__c>();
        List<Supply_Order_Line_Item__c> soLineItems = new List<Supply_Order_Line_Item__c>();
        
        final String ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        Map<Id, Integer> productToSuffix = new Map<Id, Integer>(); 
        
        for (Id soId : soToWplis.keySet()) {
            Supply_Order__c rso = originalToReverseSO.get(soId);
            
            String orderNumber = [SELECT Id, Name FROM Supply_Order__c WHERE Id=:rso.Id].Name.replace('SO-', '');
            
            for (Warehouse_Product_Line_Items__c wpli : soToWplis.get(soId)) {
                Id productId = wpli.Warehouse__r.Zydus_Product__c;
                String key = rso.Id + '-' + productId;
                
                if (!soProductKeyMap.containsKey(key)) {
                    SO_Product__c sop = new SO_Product__c(
                        Zydus_Product__c = productId,
                        Supply_Order__c = rso.Id
                    );
                    soProducts.add(sop);
                    soProductKeyMap.put(key, sop);
                }
                Integer suffixIndex = productToSuffix.containsKey(productId) ? productToSuffix.get(productId) : 1;
                String baseSuffix = '';
                Integer temp = suffixIndex;
                while (temp > 0) {
                    Integer rem = Math.mod(temp - 1, 26);
                    baseSuffix = ALPHA.substring(rem, rem + 1) + baseSuffix;
                    temp = (temp - 1) / 26;
                }
                productToSuffix.put(productId, suffixIndex + 1);
                String name = 'SOP' + String.valueOf(suffixIndex) + '/' + orderNumber + '/' + baseSuffix;
                
                Supply_Order_Line_Item__c soli = new Supply_Order_Line_Item__c(
                    Name = name,
                    Zydus_Product__c = productId,
                    Serial_Number__c = wpli.Serial_Number__c,
                    Batch_Number__c = wpli.Batch_Number__c,
                    Expiry_Date__c = wpli.Expiry_Date__c,
                    Warehouse_Product_Line_Item__c = wpli.Id,
                    Supply_Order__c = rso.Id,
                    Net_Amount__c = (wpli.Supply_Order_Line_Item__r != null) ? wpli.Supply_Order_Line_Item__r.Net_Amount__c : null,
                    Zydus_Price_Book_Entry__c = wpli.Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__c,
                    Unit_Price__c = wpli.Supply_Order_Line_Item__r.Zydus_Price_Book_Entry__r.List_Price__c,
                    SO_Product__c = soProductKeyMap.get(key).Id,
                    Manufacturing_Date__c = wpli.Manufactured_Date__c
                );
                
                System.debug('SOLI is :' + soli);
                soLineItems.add(soli);
            }
        }

        
        insert soProducts;
        
        Map<String, Id> productKeyToId = new Map<String, Id>();
        for (SO_Product__c sop : soProducts) {
            productKeyToId.put(sop.Supply_Order__c + '-' + sop.Zydus_Product__c, sop.Id);
        }
        
        Map<Id, Warehouse_Product_Line_Items__c> wpliMap = new Map<Id, Warehouse_Product_Line_Items__c>();
        for (Warehouse_Product_Line_Items__c w : wplis) {
            wpliMap.put(w.Id, w);
        }
        
        for (Supply_Order_Line_Item__c soli : soLineItems) {
            Id wpliId = soli.Warehouse_Product_Line_Item__c;
            Warehouse_Product_Line_Items__c wpli = wpliMap.get(wpliId);
            if (wpli != null) {
                Id originalSoId = wpli.GRN__r.Delivery_Challan__r.Supply_Order__c;
                Supply_Order__c rso = originalToReverseSO.get(originalSoId);
                if (rso != null) {
                    String key = rso.Id + '-' + wpli.Warehouse__r.Zydus_Product__c;
                    soli.SO_Product__c = productKeyToId.get(key);
                }
            }
        }
        
        insert soLineItems;
        for (Warehouse_Product_Line_Items__c wpli : wplis) {
            wpli.RSO_Created__c = true;
        }
        
        update wplis;
        
        for(Supply_Order__c rso:newSOs){
            NotificationService.notifyUsers(
                new Set<String>{rso.Consignor_Distributor__r.Business_Owner__c, rso.Consignee_Distributor__r.Business_Owner__c},
                rso.Id,
                'New RSO Created',
                'An RSO "' + rso.Name + '" has been created due to receipt of damaged, wrong, expired items, or other reason. Please review and take appropriate action.'
            );
        }        
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
    
}