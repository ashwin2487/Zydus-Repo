public class RDCChallanCreator implements Queueable {
    private List<Id> rsoIds;

    public RDCChallanCreator(List<Id> rsoIds) {
        this.rsoIds = rsoIds;
    }

    public void execute(QueueableContext context) {
        if (rsoIds == null || rsoIds.isEmpty()) return;

        // Get RDC record type
        Id rdcRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Delivery_Challan__c' AND DeveloperName = 'RDC'
            LIMIT 1
        ].Id;

        // Fetch RSO records
        List<Supply_Order__c> rsos = [
            SELECT Id, Name
            FROM Supply_Order__c
            WHERE Id IN :rsoIds
        ];

        // Create RDCs mapped to RSOs
        Map<Id, Delivery_Challan__c> soToDCMap = new Map<Id, Delivery_Challan__c>();
        List<Delivery_Challan__c> newDCs = new List<Delivery_Challan__c>();

        for (Supply_Order__c rso : rsos) {
            Delivery_Challan__c dc = new Delivery_Challan__c();
            dc.RecordTypeId = rdcRecordTypeId;
            dc.DC_Generated_Date__c = System.today();
            dc.Supply_Order__c = rso.Id;
            newDCs.add(dc);
        }

        if (!newDCs.isEmpty()) {
            insert newDCs;
            for (Delivery_Challan__c dc : newDCs) {
                soToDCMap.put(dc.Supply_Order__c, dc);
            }
        }

        if (soToDCMap.isEmpty()) return;

        // Fetch SOLIs for RSOs
        List<Supply_Order_Line_Item__c> solis = [
            SELECT Batch_Number__c, CGST__c, Expiry_Date__c, HSN_Code__c,
                   IGST__c, Manufacturing_Date__c, Net_Amount__c, Serial_Number__c,
                   SGST__c, Supply_Order__c, Unit_Price__c,
                   Warehouse__c, Warehouse_Product_Line_Item__c, Zydus_Price_Book_Entry__c,
                   Zydus_Product__c
            FROM Supply_Order_Line_Item__c
            WHERE Supply_Order__c IN :rsoIds
        ];

        List<Delivery_Challan_Line_Item__c> dcLineItems = new List<Delivery_Challan_Line_Item__c>();

        for (Supply_Order_Line_Item__c soli : solis) {
            Delivery_Challan__c relatedDC = soToDCMap.get(soli.Supply_Order__c);
            if (relatedDC == null) continue;

            Delivery_Challan_Line_Item__c dcli = new Delivery_Challan_Line_Item__c();
            dcli.Delivery_Challan__c = relatedDC.Id;
            dcli.Batch_Number__c = soli.Batch_Number__c;
            dcli.CGST__c = soli.CGST__c;
            dcli.Expiry_Date__c = soli.Expiry_Date__c;
            dcli.HSN_Code__c = soli.HSN_Code__c;
            dcli.IGST__c = soli.IGST__c;
            dcli.Manufacturing_Date__c = soli.Manufacturing_Date__c;
            dcli.Net_Amount__c = soli.Net_Amount__c;
            dcli.Serial_Number__c = soli.Serial_Number__c;
            dcli.SGST__c = soli.SGST__c;
            dcli.Zydus_Product__c = soli.Zydus_Product__c;
            dcli.Unit_Price__c = soli.Unit_Price__c;
            dcli.Warehouse__c = soli.Warehouse__c;
            dcli.Zydus_Product__c = soli.Zydus_Product__c;

            dcLineItems.add(dcli);
        }

        if (!dcLineItems.isEmpty()) {
            insert dcLineItems;
        }
    }
}