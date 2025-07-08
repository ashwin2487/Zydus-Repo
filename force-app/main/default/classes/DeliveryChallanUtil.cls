public without sharing class DeliveryChallanUtil {

    public static void updateWarehouseLineItems(List<Warehouse_Product_Line_Items__c> items) {
        if (items != null && !items.isEmpty()) {
            update items;
        }
    }

    public static void updateDeliveryChallanLineItems(List<Delivery_Challan_Line_Item__c> items) {
        if (items != null && !items.isEmpty()) {
            update items;
        }
    }
}