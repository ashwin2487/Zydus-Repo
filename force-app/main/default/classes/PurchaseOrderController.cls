public class PurchaseOrderController {
    
    @AuraEnabled(cacheable=true)
    public static PurchaseOrderWrapper getPurchaseOrderDetails(Id recordId) {
        Purchase_Order__c po = [
            SELECT 
            Account__c,
            Amount__c,
            ARS_Order__c,
            CloseDate__c,
            ContractId__c,
            CreatedById,
            Hospital__c,
            Is_Order_Created__c,
            LastModifiedById,
            myPurchaseOrder__c,
            Probability__c,
            Name,
            RecordTypeId,
            StageName__c,
            Supplier_Distributor__c,
            Total_Amount__c,
            Total_Ordered_Quantity__c,
            Total_Pending_Quantity__c,
            Total_Supplied_Quantity__c,
            Zydus_Price_Book__c,
            Comment__c,
            
            Supplier_Distributor__r.Name,
            Supplier_Distributor__r.Address__c,
            Supplier_Distributor__r.City__c,
            Supplier_Distributor__r.State__c,
            Supplier_Distributor__r.Account_Pin_Code__c,
            Supplier_Distributor__r.Drug_Licence_Number__c,
            Supplier_Distributor__r.GST_Number__c,
            Supplier_Distributor__r.PAN_Number__c,
            
            Account__r.Name,
            Account__r.Address__c,
            Account__r.State__c,
            Account__r.City__c,
            Account__r.Account_Pin_Code__c,
            Account__r.Drug_Licence_Number__c,
            Account__r.PAN_Number__c,
            Account__r.GST_Number__c,
            
            (SELECT 
             Id,
             Name,
             Quantity__c,
             UnitPrice__c,
             IGST__c,
             CGST__c,
             SGST__c,
             	Purchase_Order_Amount__c,
             Zydus_Product__r.Name,
             Zydus_Product__r.Diameter__c,
             Zydus_Product__r.Length__c
             FROM Purchase_Order_Products__r)
            
            FROM Purchase_Order__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        return new PurchaseOrderWrapper(po);
    }
    
    public class PurchaseOrderWrapper {
        @AuraEnabled public Purchase_Order__c purchaseOrder;
        
        public PurchaseOrderWrapper(Purchase_Order__c po) {
            this.purchaseOrder = po;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String unitTaxablePrice(Id recordId) {
        // Step 1: Get Account, Price Book, and Product from Purchase Order
        Purchase_Order__c po = [
            SELECT 
            Id, 
            Account__c, 
            Account__r.Zydus_Price_Book__c,
            (SELECT Zydus_Product__c FROM Purchase_Order_Products__r LIMIT 1)
            FROM Purchase_Order__c 
            WHERE Id = :recordId 
            LIMIT 1
        ];
        
        // Extract values
        Id priceBookId = po.Account__r.Zydus_Price_Book__c;
        if (priceBookId == null) {
            return 'No Zydus Price Book found on Account';
        }
        
        if (po.Purchase_Order_Products__r.isEmpty()) {
            return 'No Products found in Purchase Order';
        }
        
        Id productId = po.Purchase_Order_Products__r[0].Zydus_Product__c;
        if (productId == null) {
            return 'Zydus Product not found in PO Line Item';
        }
        
        // Step 2: Fetch the Unit Taxable Price from Price Book Entry
        Zydus_Price_Book_Entry__c entry = [
            SELECT Unit_Price__c 
            FROM Zydus_Price_Book_Entry__c 
            WHERE Zydus_Product__c = :productId 
            AND Zydus_Price_Book__c = :priceBookId 
            LIMIT 1
        ];
        
        // Return the price or fallback message
        return entry.Unit_Price__c != null ? String.valueOf(entry.Unit_Price__c) : 'Unit Taxable Price not found';
    }
    
    /********MANUAL PO************/
    @AuraEnabled
    public static List<Zydus_Product__c> getAllZydusProducts(){
        return [SELECT Id, Name FROM Zydus_Product__c];
    }
    
    @AuraEnabled
    public static String latestPOName(Id accountId) {
        Account acc = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
        String accName = acc.Name;
        
        String[] accParts = accName != null ? accName.split(' ') : new String[0];
        String firstWord = accParts.size() > 0 ? accParts[0] : 'Account';
        
        List<Purchase_Order__c> poList = [
            SELECT Name
            FROM Purchase_Order__c
            WHERE Name LIKE :('PO-' + firstWord + '-%')
            ORDER BY CreatedDate DESC
        ];
        
        Integer nextNumber = 1;
        
        for (Purchase_Order__c po : poList) {
            
            List<String> parts = po.Name.split('-');
            if (parts.size() == 3 && Pattern.matches('\\d+', parts[2])) {
                Integer num = Integer.valueOf(parts[2]);
                if (num >= nextNumber) {
                    nextNumber = num + 1;
                }
            }
        }
        
        String nextNumberStr = String.valueOf(100000 + nextNumber).substring(1);
        return 'PO-' + firstWord + '-' + nextNumberStr;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Zydus_Price_Book_Entry__c getPriceBookEntry(Id productId, Id priceBookId) {
        List<Zydus_Price_Book_Entry__c> entries = [
            SELECT Id, Name, Zydus_Product__c, Zydus_Price_Book__c, Bill_Discount_Amount__c,
            Credit_Note_Amount__c, Is_Active__c, Minimum_Order_Quantity_MOQ__c,
            List_Price__c, Unit_Price__c, Use_Brand_Pricing__c
            FROM Zydus_Price_Book_Entry__c
            WHERE Zydus_Product__c = :productId
            AND Zydus_Price_Book__c = :priceBookId
            LIMIT 1
        ];
        return entries.isEmpty() ? null : entries[0];
    }
    
    @AuraEnabled
    public static Zydus_Price_Book_Entry__c savePriceBookEntry(String productId, String priceBookId, Boolean useBrandPricing) {
        try {
            Zydus_Price_Book_Entry__c entry = new Zydus_Price_Book_Entry__c(
                Zydus_Product__c        = productId,
                Zydus_Price_Book__c     = priceBookId,
                Use_Brand_Pricing__c    = useBrandPricing,
                Is_Active__c            = true
            );
            
            insert entry;
            
            entry = [
                SELECT Id, Name, Zydus_Product__c, Zydus_Price_Book__c, Bill_Discount_Amount__c,
                Credit_Note_Amount__c, Is_Active__c, Minimum_Order_Quantity_MOQ__c,
                List_Price__c, Unit_Price__c, Use_Brand_Pricing__c
                FROM Zydus_Price_Book_Entry__c
                WHERE Id = :entry.Id
                LIMIT 1
            ];
            
            return entry;
            
        } catch (DmlException e) {
            throw new AuraHandledException(
                'Unable to create Price Book Entry: ' + e.getDmlMessage(0)
            );
        }
    }
    
    public class ProductInput {
        public String productId;
        public String productName;
        public Decimal unitPrice;
        public Decimal listPrice;
        public Decimal mrp;
        public Integer minOrderQty;
        public Decimal billDiscount;
        public Decimal creditNote;
        public Decimal unitTaxablePrice;
        public Boolean useBrandPricing;
    }
    
    public class PORequest {
        public String accountId;
        public String poName;
        public String supplierId;
        public String priceBookId;
        public List<ProductInput> products;
    }
    
    public class AddProductsRequest {
        public String poId;
        public String selectedPriceBookId;
        public String accountId;
        public List<ProductInput> selectedProducts;
    }
    
    @AuraEnabled
    public static Id createManualPurchaseOrder(String payload) {
        ID userId = UserInfo.getUserId();
        
        User currentUser = [
            SELECT Id, UserRole.Name, Profile.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, Name
            FROM RecordType
            WHERE SObjectType = 'Purchase_Order__c'
        ]) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        
        PORequest request = (PORequest) JSON.deserialize(payload, PORequest.class);
        
        if (request == null || String.isBlank(request.accountId) || String.isBlank(request.supplierId) ||
            String.isBlank(request.priceBookId) || request.products == null || request.products.isEmpty()) {
                throw new AuraHandledException('Missing required Purchase Order data.');
            }
        
        Account curAcc = [SELECT Id, Business_Owner__c, State__c, Parent.State__c FROM Account WHERE Id = :request.accountId];
        
        if (currentUser.Id != curAcc.Business_Owner__c) {
            throw new AuraHandledException('Access Denied: Only the designated Business Owner is authorized to create a Purchase Order.');
        }
        
        String buyerState = curAcc.State__c;
        String supplierState = curAcc.Parent != null ? curAcc.Parent.State__c : null;
        String supplyType = (buyerState == supplierState) ? 'Intra-State' : 'Inter-State';
        
        Set<Id> productIds = new Set<Id>();
        for (ProductInput prod : request.products) {
            if (!String.isBlank(prod.productId)) {
                productIds.add(prod.productId);
            }
        }
        
        Map<Id, Zydus_Product__c> productMap = new Map<Id, Zydus_Product__c>(
            [SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :productIds]
        );
        
        Set<Id> hsnIds = new Set<Id>();
        Map<Id, Id> productToHSNMap = new Map<Id, Id>();
        for (Zydus_Product__c prod : productMap.values()) {
            if (prod.HSN_Code__c != null) {
                productToHSNMap.put(prod.Id, prod.HSN_Code__c);
                hsnIds.add(prod.HSN_Code__c);
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
        ]) {
            String taxKey = tax.HSN_Code__c + '_' + tax.Tax_Master__r.State__c + '_' + tax.Supply_Type__c;
            taxRateMap.put(taxKey, tax);
        }
        
        Purchase_Order__c po = new Purchase_Order__c(
            Name = request.poName,
            Account__c = request.accountId,
            Supplier_Distributor__c = request.supplierId,
            Zydus_Price_Book__c = request.priceBookId,
            StageName__c = 'Draft Purchase Order',
            RecordTypeId = recordTypeMap.get('Manual Purchase Order')
        );
        insert po;
        
        List<Purchase_Order_Product__c> productsToInsert = new List<Purchase_Order_Product__c>();
        for (ProductInput prod : request.products) {
            if (String.isBlank(prod.productId) || prod.minOrderQty == null) continue;
            
            Decimal quantity = prod.minOrderQty;
            Decimal unitPrice = prod.unitPrice != null ? prod.unitPrice : 0;
            Decimal taxableValue = quantity * unitPrice;
            
            Decimal cgst = 0, sgst = 0, igst = 0;
            Id hsnId = productToHSNMap.get(prod.productId);
            if (hsnId != null) {
                String taxKey = hsnId + '_' + supplierState + '_' + supplyType;
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
            
            productsToInsert.add(new Purchase_Order_Product__c(
                Purchase_Order__c = po.Id,
                Zydus_Product__c = prod.productId,
                Quantity__c = quantity,
                UnitPrice__c = unitPrice,
                List_Price__c = prod.listPrice,
                Pending_Quantity__c = quantity,
                SO_Status__c = 'SO Pending',
                Zydus_Price_Book__c = request.priceBookId,
                HSN_Code__c = hsnId,
                CGST__c = cgst,
                SGST__c = sgst,
                IGST__c = igst
            ));
        }
        
        if (!productsToInsert.isEmpty()) {
            insert productsToInsert;
        }
        
        return po.Id;
    }
    
    @AuraEnabled
    public static void addProductsToPO(String payload) {
        ID userId = UserInfo.getUserId();
        
        User currentUser = [
            SELECT Id, UserRole.Name, Profile.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        if (String.isBlank(payload)) {
            throw new AuraHandledException('Payload cannot be empty.');
        }
        
        AddProductsRequest request = (AddProductsRequest) JSON.deserialize(payload, AddProductsRequest.class);
        
        Account curAcc = [SELECT Id, Business_Owner__c, State__c, Parent.State__c FROM Account WHERE Id = :request.accountId];
        
        if (currentUser.Id != curAcc.Business_Owner__c) {
            throw new AuraHandledException('Access Denied: Only the designated Business Owner is authorized to Edit a Purchase Order.');
        }
        
        Purchase_Order__c PO = [SELECT Id, StageName__c FROM Purchase_Order__c WHERE Id = :request.poId];
        
        if (PO.StageName__c != 'Draft Purchase Order') {
            throw new AuraHandledException('Purchase Order cannot be edited after it has been approved.');
        }
        
        List<Purchase_Order_Product__c> existingProducts = [
            SELECT Id, Zydus_Product__c
            FROM Purchase_Order_Product__c
            WHERE Purchase_Order__c = :request.poId
        ];
        
        Map<String, Purchase_Order_Product__c> existingProdMap = new Map<String, Purchase_Order_Product__c>();
        for (Purchase_Order_Product__c poProd : existingProducts) {
            if (poProd.Zydus_Product__c != null) {
                existingProdMap.put(poProd.Zydus_Product__c, poProd);
            }
        }
        
        Set<Id> productIds = new Set<Id>();
        for (ProductInput prod : request.selectedProducts) {
            if (!String.isBlank(prod.productId)) {
                productIds.add(prod.productId);
            }
        }
        
        Map<Id, Zydus_Product__c> productMap = new Map<Id, Zydus_Product__c>(
            [SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :productIds]
        );
        
        Set<Id> hsnIds = new Set<Id>();
        Map<Id, Id> productToHSNMap = new Map<Id, Id>();
        for (Zydus_Product__c prod : productMap.values()) {
            if (prod.HSN_Code__c != null) {
                productToHSNMap.put(prod.Id, prod.HSN_Code__c);
                hsnIds.add(prod.HSN_Code__c);
            }
        }
        
        String buyerState = curAcc.State__c;
        String supplierState = curAcc.Parent != null ? curAcc.Parent.State__c : null;
        String supplyType = (buyerState == supplierState) ? 'Intra-State' : 'Inter-State';
        
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
        ]) {
            String taxKey = tax.HSN_Code__c + '_' + tax.Tax_Master__r.State__c + '_' + tax.Supply_Type__c;
            taxRateMap.put(taxKey, tax);
        }
        
        List<Purchase_Order_Product__c> productsToInsert = new List<Purchase_Order_Product__c>();
        List<Purchase_Order_Product__c> productsToUpdate = new List<Purchase_Order_Product__c>();
        
        for (ProductInput prod : request.selectedProducts) {
            if (String.isBlank(prod.productId) || prod.minOrderQty == null) continue;
            
            Decimal quantity = prod.minOrderQty;
            Decimal unitPrice = prod.unitPrice != null ? prod.unitPrice : 0;
            Decimal taxableValue = quantity * unitPrice;
            
            Decimal cgst = 0, sgst = 0, igst = 0;
            Id hsnId = productToHSNMap.get(prod.productId);
            if (hsnId != null) {
                String taxKey = hsnId + '_' + supplierState + '_' + supplyType;
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
            
            if (existingProdMap.containsKey(prod.productId)) {
                Purchase_Order_Product__c existingProd = existingProdMap.get(prod.productId);
                existingProd.Quantity__c = quantity;
                existingProd.UnitPrice__c = unitPrice;
                existingProd.List_Price__c = prod.listPrice;
                existingProd.Pending_Quantity__c = quantity;
                existingProd.SO_Status__c = 'SO Pending';
                existingProd.CGST__c = cgst;
                existingProd.SGST__c = sgst;
                existingProd.IGST__c = igst;
                existingProd.HSN_Code__c = hsnId;
                
                productsToUpdate.add(existingProd);
                existingProdMap.remove(prod.productId);
            } else {
                productsToInsert.add(new Purchase_Order_Product__c(
                    Purchase_Order__c = request.poId,
                    Zydus_Product__c = prod.productId,
                    Quantity__c = quantity,
                    UnitPrice__c = unitPrice,
                    List_Price__c = prod.listPrice,
                    Pending_Quantity__c = quantity,
                    SO_Status__c = 'SO Pending',
                    Zydus_Price_Book__c = request.selectedPriceBookId,
                    CGST__c = cgst,
                    SGST__c = sgst,
                    IGST__c = igst,
                    HSN_Code__c = hsnId
                ));
            }
        }
        
        if (!productsToInsert.isEmpty()) insert productsToInsert;
        if (!productsToUpdate.isEmpty()) update productsToUpdate;
    }
    @AuraEnabled
    public static void manualPOClosure(Id recordId, String reason) {
        Id userId = UserInfo.getUserId();
        
        if (String.isBlank(reason)) {
            throw new AuraHandledException('Reason for closure is required.');
        }
        
        if (recordId == null) {
            throw new AuraHandledException('Invalid Purchase Order ID.');
        }
        
        Purchase_Order__c po = [
            SELECT Id, StageName__c, Manual_Closure_Reason__c,
            Supplier_Distributor__r.Business_Owner__c,Supplier_Distributor__c
            FROM Purchase_Order__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        if (po.Supplier_Distributor__c == null || po.Supplier_Distributor__r.Business_Owner__c == null) {
            throw new AuraHandledException('Supplier Distributor or Business Owner not defined.');
        }
        
        if (userId != po.Supplier_Distributor__r.Business_Owner__c) {
            throw new AuraHandledException('Unauthorized Access - only the supplier distributor can close the order manually.');
        }
        
        po.StageName__c = 'Purchase Order Closed';
        po.Manual_Closure_Reason__c = reason;
        po.CloseDate__c = System.today();
        
        update po;
    }
    
    @AuraEnabled
    public static void approvePurchaseOrder(String recordId) {
        Id currentUserId = UserInfo.getUserId();
        
        Purchase_Order__c po = [
            SELECT Id, StageName__c, Account__r.Business_Owner__c, Supplier_Distributor__r.Business_Owner__c,
            Supplier_Distributor__c,RecordType.Name
            FROM Purchase_Order__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        if(po.RecordType.Name != 'Hopsital Purchase Order'){
            if (po.StageName__c != 'Draft Purchase Order') {
                throw new AuraHandledException('Action Denied: Only Purchase Orders in Draft state can be approved.');
            }
            
            if (po.Account__r == null || po.Account__r.Business_Owner__c == null || currentUserId != po.Account__r.Business_Owner__c) {
                throw new AuraHandledException('Access Denied: You are not authorized to approve this Purchase Order.');
            }
            
        }
        
        po.StageName__c = 'Approve Purchase Order';
        update po;
    }
    
}