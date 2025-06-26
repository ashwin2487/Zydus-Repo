public class SupplyOrderTriggerHandler {

    public static void createDeliveryChallans(List<Supply_Order__c> newSalesOrders) {
        Map<Id, Supply_Order__c> orderMap = new Map<Id, Supply_Order__c>();
        for (Supply_Order__c so : newSalesOrders) {
            orderMap.put(so.Id, so);
        }

        List<Supply_Order_Line_Item__c> orderLineItems = [
            SELECT Id, Supply_Order__c, Product__c, Quantity__c, Discount__c, CGST__c, SGST__c, IGST__c, Net_Amount__c
            FROM Supply_Order_Line_Item__c
            WHERE Supply_Order__c IN :orderMap.keySet()
        ];

        Map<Id, List<Supply_Order_Line_Item__c>> orderToLineItems = new Map<Id, List<Supply_Order_Line_Item__c>>();
        for (Supply_Order_Line_Item__c line : orderLineItems) {
            if (!orderToLineItems.containsKey(line.Supply_Order__c)) {
                orderToLineItems.put(line.Supply_Order__c, new List<Supply_Order_Line_Item__c>());
            }
            orderToLineItems.get(line.Supply_Order__c).add(line);
        }

        List<Delivery_Challan__c> challansToInsert = new List<Delivery_Challan__c>();
        Map<Id, Delivery_Challan__c> orderToChallanMap = new Map<Id, Delivery_Challan__c>();

        for (Supply_Order__c so : newSalesOrders) {
            Delivery_Challan__c dc = new Delivery_Challan__c();
            dc.Supply_Order__c = so.Id;
            challansToInsert.add(dc);
            orderToChallanMap.put(so.Id, dc);
        }

        insert challansToInsert;

        List<Delivery_Challan_Line_Item__c> challanLineItems = new List<Delivery_Challan_Line_Item__c>();

        for (Supply_Order__c so : newSalesOrders) {
            Delivery_Challan__c dc = orderToChallanMap.get(so.Id);
            List<Supply_Order_Line_Item__c> lineItems = orderToLineItems.get(so.Id);

            if (lineItems != null) {
                for (Supply_Order_Line_Item__c soLine : lineItems) {
                    Delivery_Challan_Line_Item__c dcLine = new Delivery_Challan_Line_Item__c();
                    dcLine.Delivery_Challan__c = dc.Id;
                    dcLine.Product__c = soLine.Product__c;

                    challanLineItems.add(dcLine);
                }
            }
        }
        if (!challanLineItems.isEmpty()) {
            insert challanLineItems;
        }
    }
}