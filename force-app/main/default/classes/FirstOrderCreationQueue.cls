public class FirstOrderCreationQueue implements Queueable {
    private List<Id> accountIds;
    
    public FirstOrderCreationQueue(List<Id> accountIds) {
        this.accountIds = accountIds;
    }
    
    public void execute(QueueableContext context) {
        List<Account> accounts = [
            SELECT Id, Name, Zydus_Price_Book__c, Business_Owner__c, ParentId, 
            L1_Approved__c, L2_Approved__c, Active__c, State__c,
            Parent.State__c
            FROM Account
            WHERE Id IN :accountIds
        ];

        if (accounts.isEmpty()) return;
        
        Map<Id, Account> accountsMap = new Map<Id, Account>();
        for (Account acc : accounts) {
            accountsMap.put(acc.Id, acc);
        }
        
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, Name FROM RecordType WHERE SObjectType = 'Purchase_Order__c'
        ]) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        
        Id purchaseOrderRtId = recordTypeMap.get('Purchase Order');
        if (purchaseOrderRtId == null) return;
        
        List<Purchase_Order__c> poToInsert = new List<Purchase_Order__c>();
        Set<Id> pricebookIds = new Set<Id>();
        
        for (Account acc : accounts) {
            if (acc.Active__c && acc.L1_Approved__c && acc.L2_Approved__c &&
                acc.Zydus_Price_Book__c != null && acc.Business_Owner__c != null && acc.ParentId != null) {
                    
                    Purchase_Order__c po = new Purchase_Order__c();
                    po.Name = generateNextPOName(acc.Id);
                    po.Account__c = acc.Id;
                    po.Zydus_Price_Book__c = acc.Zydus_Price_Book__c;
                    po.RecordTypeId = purchaseOrderRtId;
                    po.Supplier_Distributor__c = acc.ParentId;
                    po.StageName__c = 'Draft Purchase Order';
                    po.ARS_Order__c = true;
                    
                    poToInsert.add(po);
                    pricebookIds.add(acc.Zydus_Price_Book__c);
                }
        }
        
        insert poToInsert;
        
        List<Zydus_Price_Book_Entry__c> pbes = [
            SELECT Id, Zydus_Product__c, List_Price__c, Bill_Discount_Amount__c, Unit_Price__c,
            Minimum_Order_Quantity_MOQ__c, Credit_Note_Amount__c, Zydus_Price_Book__c,
            Is_Active__c
            FROM Zydus_Price_Book_Entry__c
            WHERE Zydus_Price_Book__c IN :pricebookIds AND Is_Active__c = TRUE
        ];
        
        Set<Id> pbeProductIds = new Set<Id>();
        for (Zydus_Price_Book_Entry__c pbe : pbes) {
            pbeProductIds.add(pbe.Zydus_Product__c);
        }
        
        Map<Id, Id> productToHSNMap = new Map<Id, Id>();
        Set<Id> hsnIds = new Set<Id>();
        for (Zydus_Product__c zp : [
            SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :pbeProductIds
        ]) {
            if (zp.HSN_Code__c != null) {
                productToHSNMap.put(zp.Id, zp.HSN_Code__c);
                hsnIds.add(zp.HSN_Code__c);
            }
        }
        
        Date today = Date.today();
        Map<String, HSN_Tax_Master_Link__c> taxRateMap = new Map<String, HSN_Tax_Master_Link__c>();
        for (HSN_Tax_Master_Link__c tax : [
            SELECT Id, HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c,
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
        
        List<Purchase_Order_Product__c> popToInsert = new List<Purchase_Order_Product__c>();
        
        for (Purchase_Order__c po : poToInsert) {
            List<Zydus_Price_Book_Entry__c> entries = new List<Zydus_Price_Book_Entry__c>();
            for (Zydus_Price_Book_Entry__c pbe : pbes) {
                if (pbe.Zydus_Price_Book__c == po.Zydus_Price_Book__c) {
                    entries.add(pbe);
                }
            }
            
            Account acc = accountsMap.get(po.Account__c);
            String buyerState = acc.State__c;
            String supplierState = acc.Parent.State__c;
            String supplyType = buyerState == supplierState ? 'Intra-State' : 'Inter-State';
            
            for (Zydus_Price_Book_Entry__c pbe : entries) {
                Id hsnId = productToHSNMap.get(pbe.Zydus_Product__c);
                if (hsnId == null) continue;
                
                String taxKey = hsnId + '_' + supplierState + '_' + supplyType;
                HSN_Tax_Master_Link__c tax = taxRateMap.get(taxKey);
                
                Decimal quantity = pbe.Minimum_Order_Quantity_MOQ__c != null ? pbe.Minimum_Order_Quantity_MOQ__c : 1;
                Decimal taxableValue = quantity * pbe.Unit_Price__c;
                
                Decimal cgstAmt = 0, sgstAmt = 0, igstAmt = 0;
                if (tax != null) {
                    if (supplyType == 'Intra-State') {
                        cgstAmt = taxableValue * (tax.CGST__c / 100);
                        sgstAmt = taxableValue * (tax.SGST__c / 100);
                    } else {
                        igstAmt = taxableValue * (tax.IGST__c / 100);
                    }
                }
                
                Purchase_Order_Product__c pop = new Purchase_Order_Product__c();
                pop.Purchase_Order__c = po.Id;
                pop.Zydus_Product__c = pbe.Zydus_Product__c;
                pop.Quantity__c = quantity;
                pop.UnitPrice__c = pbe.Unit_Price__c;
                pop.List_Price__c = pbe.List_Price__c;
                pop.SO_Status__c = 'SO Pending';
                pop.Pending_Quantity__c = quantity;
                pop.Zydus_Price_Book_Entry__c = pbe.Id;
                pop.Zydus_Price_Book__c = pbe.Zydus_Price_Book__c;
                pop.CGST__c = cgstAmt;
                pop.SGST__c = sgstAmt;
                pop.IGST__c = igstAmt;
                pop.HSN_Code__c = hsnId;
                popToInsert.add(pop);
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
}