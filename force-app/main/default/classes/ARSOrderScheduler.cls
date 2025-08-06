global without sharing class ARSOrderScheduler implements Schedulable {
    
    global void execute(SchedulableContext sc) {
        Date today = Date.today();
        
        List<Account> accs = [
            SELECT Id, Name, ParentId, Zydus_Price_Book__c, State__c,
            Active__c, L1_Approved__c, L2_Approved__c,
            Parent.State__c
            FROM Account
            WHERE DL_Active__c = TRUE AND Active__c = TRUE AND L1_Approved__c = TRUE AND L2_Approved__c = TRUE
        ];
        Map<Id, Account> accountsMap = new Map<Id, Account>(accs);
        Set<Id> accIds = new Set<Id>(accountsMap.keySet());
        
        AggregateResult[] stockCounts = [SELECT Warehouse__r.Zydus_Product__c productId, COUNT(Id) stockCount
                                         FROM Warehouse_Product_Line_Items__c
                                         WHERE Connected_warehouse__r.Account__c IN :accIds
                                         AND Status__c = 'Available' AND Condition__c = 'Good'
                                         GROUP BY Warehouse__r.Zydus_Product__c
                                        ];
        
        Map<Id, Integer> productIdToStockCount = new Map<Id, Integer>();
        for (AggregateResult ar : stockCounts) {
            Id productId = (Id) ar.get('productId');
            Integer count = (Integer) ar.get('stockCount');
            productIdToStockCount.put(productId, count);
        }
        
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Purchase_Order__c']) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        Id purchaseOrderRtId = recordTypeMap.get('Purchase Order');
        if (purchaseOrderRtId == null) return;
        
        Set<Id> pricebookIds = new Set<Id>();
        for (Account acc : accs) {
            if (acc.Zydus_Price_Book__c != null) pricebookIds.add(acc.Zydus_Price_Book__c);
        }
        
        List<Zydus_Price_Book_Entry__c> pbes = [SELECT Id, Zydus_Product__c, ARS_Minimum_Stock_Threshold__c,
                                                Unit_Price__c, Minimum_Order_Quantity_MOQ__c,
                                                Zydus_Price_Book__c, Zydus_Product__r.MRP__c,
                                                Is_Active__c
                                                FROM Zydus_Price_Book_Entry__c
                                                WHERE Zydus_Price_Book__c IN :pricebookIds AND Is_Active__c = TRUE
                                               ];
        
        Map<Id, List<Zydus_Price_Book_Entry__c>> pbToEntries = new Map<Id, List<Zydus_Price_Book_Entry__c>>();
        Set<Id> productIds = new Set<Id>();
        
        for (Zydus_Price_Book_Entry__c pbe : pbes) {
            productIds.add(pbe.Zydus_Product__c);
            if (!pbToEntries.containsKey(pbe.Zydus_Price_Book__c)) {
                pbToEntries.put(pbe.Zydus_Price_Book__c, new List<Zydus_Price_Book_Entry__c>());
            }
            pbToEntries.get(pbe.Zydus_Price_Book__c).add(pbe);
        }
        
        Map<Id, Id> productToHSNMap = new Map<Id, Id>();
        Set<Id> hsnIds = new Set<Id>();
        for (Zydus_Product__c zp : [SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :productIds]) {
            if (zp.HSN_Code__c != null) {
                productToHSNMap.put(zp.Id, zp.HSN_Code__c);
                hsnIds.add(zp.HSN_Code__c);
            }
        }
        
        Map<String, HSN_Tax_Master_Link__c> taxRateMap = new Map<String, HSN_Tax_Master_Link__c>();
        for (HSN_Tax_Master_Link__c tax : [SELECT Id, HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c,
                                           Tax_Master__r.State__c
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
        
        List<Purchase_Order__c> poToInsert = new List<Purchase_Order__c>();
        List<Purchase_Order_Product__c> popToInsert = new List<Purchase_Order_Product__c>();
        
        for (Account acc : accs) {
            if (acc.Zydus_Price_Book__c == null || acc.ParentId == null) continue;
            
            List<Zydus_Price_Book_Entry__c> entries = pbToEntries.get(acc.Zydus_Price_Book__c);
            if (entries == null || entries.isEmpty()) continue;
            
            List<Zydus_Price_Book_Entry__c> entriesToOrder = new List<Zydus_Price_Book_Entry__c>();
            
            for (Zydus_Price_Book_Entry__c pbe : entries) {
                if (
                    pbe.ARS_Minimum_Stock_Threshold__c != null &&
                    productIdToStockCount.containsKey(pbe.Zydus_Product__c)
                ) {
                    Decimal threshold = pbe.ARS_Minimum_Stock_Threshold__c;
                    Integer currentStock = productIdToStockCount.get(pbe.Zydus_Product__c);
                    
                    if (currentStock < threshold) {
                        entriesToOrder.add(pbe);
                    }
                }
                
            }
            
            if (!entriesToOrder.isEmpty()) {
                Purchase_Order__c po = new Purchase_Order__c();
                po.Name = generateNextPOName(acc.Id);
                po.Account__c = acc.Id;
                po.Zydus_Price_Book__c = acc.Zydus_Price_Book__c;
                po.RecordTypeId = purchaseOrderRtId;
                po.Supplier_Distributor__c = acc.ParentId;
                po.StageName__c = 'Draft Purchase Order';
                po.ARS_Order__c = true;
                poToInsert.add(po);
                
                String buyerState = acc.State__c;
                String supplierState = acc.Parent.State__c;
                String supplyType = (buyerState == supplierState) ? 'Intra-State' : 'Inter-State';
                
                for (Zydus_Price_Book_Entry__c pbe : entriesToOrder) {
                    Id hsnId = productToHSNMap.get(pbe.Zydus_Product__c);
                    if (hsnId == null) continue;
                    
                    String taxKey = hsnId + '_' + supplierState + '_' + supplyType;
                    HSN_Tax_Master_Link__c tax = taxRateMap.get(taxKey);
                    
                    Decimal qty = (pbe.Minimum_Order_Quantity_MOQ__c != null) ? pbe.Minimum_Order_Quantity_MOQ__c : 1;
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
                    pop.Zydus_Product__c = pbe.Zydus_Product__c;
                    pop.Quantity__c = qty;
                    pop.UnitPrice__c = pbe.Unit_Price__c;
                    pop.List_Price__c = pbe.Zydus_Product__r.MRP__c;
                    pop.SO_Status__c = 'SO Pending';
                    pop.Pending_Quantity__c = qty;
                    pop.Zydus_Price_Book_Entry__c = pbe.Id;
                    pop.Zydus_Price_Book__c = pbe.Zydus_Price_Book__c;
                    pop.HSN_Code__c = hsnId;
                    pop.CGST__c = cgst;
                    pop.SGST__c = sgst;
                    pop.IGST__c = igst;
                    popToInsert.add(pop);
                }
            }
        }
        
        if (!poToInsert.isEmpty()) {
            insert poToInsert;
        }
        
        Integer popIndex = 0;
        for (Purchase_Order__c po : poToInsert) {
            for (Integer i = 0; i < popToInsert.size(); i++) {
                Purchase_Order_Product__c pop = popToInsert[i];
                if (pop.Purchase_Order__c == null) {
                    pop.Purchase_Order__c = po.Id;
                    popIndex++;
                    if (popIndex >= popToInsert.size()) break;
                }
            }
        }
        
        if (!popToInsert.isEmpty()) {
            insert popToInsert;
        }
    }
    
    private static String generateNextPOName(Id accountId) {
        Account acc = [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1];
        String[] parts = acc.Name != null ? acc.Name.split(' ') : new String[0];
        String prefix = parts.size() > 0 ? parts[0] : 'Account';
        
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
    
    public static void scheduleJob() {
        String cronExp = '0 0 0 * * ?';
        String jobName = 'ARS_Purchase_Order_Creation';
        ARSOrderScheduler job = new ARSOrderScheduler();
        System.schedule(jobName, cronExp, job);
    }
}