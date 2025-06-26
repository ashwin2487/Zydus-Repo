global class DeliveryChallanRSOCreator implements Schedulable {
    global void execute(SchedulableContext sc) {
        createRSOForInvalidDCs();
    }

    public static void createRSOForInvalidDCs() {
        Date daysAgo170 = Date.today().addDays(-170);
        
        Id rsoRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Supply_Order__c' AND DeveloperName = 'RSO'
            LIMIT 1
        ].Id;

        List<Delivery_Challan__c> allDCs = [
            SELECT Id, Total_Quantity__c,
                   Invoiced_By_Parent_Account_Quantity__c,
                   Invoiced_To_Hospital_Quantity__c,
                   Supply_Order__c,
                   Supply_Order__r.SO_Generated_Date__c
            FROM Delivery_Challan__c
            WHERE Supply_Order__c != null
        ];

        Map<Id, Id> dcToNewSOMap = new Map<Id, Id>();
        List<Supply_Order__c> supplyOrdersToInsert = new List<Supply_Order__c>();

        for (Delivery_Challan__c dc : allDCs) {
            Decimal totalQty = dc.Total_Quantity__c != null ? dc.Total_Quantity__c : 0;
            Decimal parentQty = dc.Invoiced_By_Parent_Account_Quantity__c != null ? dc.Invoiced_By_Parent_Account_Quantity__c : 0;
            Decimal hospitalQty = dc.Invoiced_To_Hospital_Quantity__c != null ? dc.Invoiced_To_Hospital_Quantity__c : 0;
            Date soGeneratedDate = dc.Supply_Order__r.SO_Generated_Date__c;

            Boolean overInvoiced = parentQty > totalQty || hospitalQty > totalQty;

            if (overInvoiced && soGeneratedDate != null && soGeneratedDate <= daysAgo170) {
                Supply_Order__c newSO = new Supply_Order__c();
                newSO.Is_Auto_RSO__c = true;
                newSO.RecordTypeId = rsoRecordTypeId;
                newSO.Supply_Order__c = dc.Supply_Order__c;
                supplyOrdersToInsert.add(newSO);
                dcToNewSOMap.put(dc.Id, null);
            }
        }

        if (!supplyOrdersToInsert.isEmpty()) {
            insert supplyOrdersToInsert;

            Integer i = 0;
            for (Id dcId : dcToNewSOMap.keySet()) {
                dcToNewSOMap.put(dcId, supplyOrdersToInsert[i].Id);
                i++;
            }
            cloneSupplyOrderLineItems(dcToNewSOMap);
        }
    }

    public static void cloneSupplyOrderLineItems(Map<Id, Id> dcToNewSOMap) {
        Set<Id> originalSOIds = new Set<Id>();
        Map<Id, Id> oldToNewSOMap = new Map<Id, Id>();
        for (Id dcId : dcToNewSOMap.keySet()) {
            Delivery_Challan__c dc = [
                SELECT Supply_Order__c FROM Delivery_Challan__c WHERE Id = : dcId
                LIMIT 1
            ];
            if (dc.Supply_Order__c != null) {
                originalSOIds.add(dc.Supply_Order__c);
                oldToNewSOMap.put(dc.Supply_Order__c, dcToNewSOMap.get(dcId));
            }
        }

        List<Supply_Order_Line_Item__c> originalLineItems = [
            SELECT Batch_Number__c, CGST__c, Expiry_Date__c,
                   HSN_Code__c, IGST__c, Manufacturing_Date__c, Net_Amount__c,
                   Serial_Number__c, Supply_Order__c, Unit_Price__c,
                   Warehouse__c, Warehouse_Product_Line_Item__c,
                   Zydus_Price_Book_Entry__c, Zydus_Product__c
            FROM Supply_Order_Line_Item__c
            WHERE Supply_Order__c IN :originalSOIds
        ];

        List<Supply_Order_Line_Item__c> clonedLineItems = new List<Supply_Order_Line_Item__c>();

        for (Supply_Order_Line_Item__c orig : originalLineItems) {
            Id newSOId = oldToNewSOMap.get(orig.Supply_Order__c);
            if (newSOId != null) {
                Supply_Order_Line_Item__c clone = new Supply_Order_Line_Item__c();
                clone.Batch_Number__c = orig.Batch_Number__c;
                clone.CGST__c = orig.CGST__c;
                clone.Expiry_Date__c = orig.Expiry_Date__c;
                clone.HSN_Code__c = orig.HSN_Code__c;
                clone.IGST__c = orig.IGST__c;
                clone.Manufacturing_Date__c = orig.Manufacturing_Date__c;
                clone.Net_Amount__c = orig.Net_Amount__c;
                clone.Serial_Number__c = orig.Serial_Number__c;
                clone.SO_Product__c = orig.SO_Product__c;
                clone.Supply_Order__c = newSOId;
                clone.Unit_Price__c = orig.Unit_Price__c;
                clone.Warehouse__c = orig.Warehouse__c;
                clone.Warehouse_Product_Line_Item__c = orig.Warehouse_Product_Line_Item__c;
                clone.Zydus_Price_Book_Entry__c = orig.Zydus_Price_Book_Entry__c;
                clone.Zydus_Product__c = orig.Zydus_Product__c;
                clonedLineItems.add(clone);
            }
        }

        if (!clonedLineItems.isEmpty()) {
            insert clonedLineItems;
        }
        List<Id> rsoIds = new List<Id>(dcToNewSOMap.values());
        System.enqueueJob(new RDCChallanCreator(rsoIds));
    }
}