public class warehouseProductLineItemTriggerHandler {
    public static void warehouseProductUpdate(List<Warehouse_Product_Line_Items__c> newRecords, List<Warehouse_Product_Line_Items__c> oldRecords) {
        
        List<Warehouse_Product__c> lastGoodsReceiptUpdateList = new List<Warehouse_Product__c>();
        List<Warehouse_Product__c> lastUsageDateUpdateList = new List<Warehouse_Product__c>();
        Set<Id> warehouseProductIds = new Set<ID>(); 
        
        // Handle Insert Logic
        if (oldRecords == null) {
            for (Warehouse_Product_Line_Items__c cur : newRecords) {
                if (cur.Status__c == 'Available' && cur.Warehouse__c != null) {
                    warehouseProductIds.add(cur.Warehouse__c);
                }
            }

            Map<Id, Warehouse_Product_Line_Items__c> latestGoodsReceiptMap = new Map<Id, Warehouse_Product_Line_Items__c>();

            for (Warehouse_Product_Line_Items__c item : [
                SELECT Id, Warehouse__c, CreatedDate 
                FROM Warehouse_Product_Line_Items__c 
                WHERE Warehouse__c IN :warehouseProductIds 
                ORDER BY CreatedDate DESC
            ]) {
                if (!latestGoodsReceiptMap.containsKey(item.Warehouse__c)) {
                    latestGoodsReceiptMap.put(item.Warehouse__c, item);
                }
            }

            for (Id warehouseId : latestGoodsReceiptMap.keySet()) {
                Warehouse_Product__c wp = new Warehouse_Product__c(
                    Id = warehouseId,
                    Last_goods_receipt_date__c = latestGoodsReceiptMap.get(warehouseId).CreatedDate.date()
                );
                lastGoodsReceiptUpdateList.add(wp);
            }

            if (!lastGoodsReceiptUpdateList.isEmpty()) {
                update lastGoodsReceiptUpdateList;
            }
        }

        // Handle Update Logic
        if (oldRecords != null) {
            Map<Id, Warehouse_Product_Line_Items__c> newMap = new Map<Id, Warehouse_Product_Line_Items__c>();
            Map<Id, Warehouse_Product_Line_Items__c> oldMap = new Map<Id, Warehouse_Product_Line_Items__c>();

            for (Warehouse_Product_Line_Items__c newItem : newRecords) {
                if (newItem.Status__c == 'Consumed' && newItem.Warehouse__c != null) {
                    newMap.put(newItem.Id, newItem);
                }
            }

            for (Warehouse_Product_Line_Items__c oldItem : oldRecords) {
                if (oldItem.Status__c != 'Consumed' && oldItem.Warehouse__c != null) {
                    oldMap.put(oldItem.Id, oldItem);
                }
            }

            for (Id id : newMap.keySet()) {
                if (oldMap.containsKey(id)) {
                    Warehouse_Product_Line_Items__c newItem = newMap.get(id);
                    Warehouse_Product_Line_Items__c oldItem = oldMap.get(id);
                    if (newItem.Status__c != oldItem.Status__c) {
                        warehouseProductIds.add(newItem.Warehouse__c);
                    }
                }
            }

            Map<Id, Warehouse_Product_Line_Items__c> latestUsageMap = new Map<Id, Warehouse_Product_Line_Items__c>();

            for (Warehouse_Product_Line_Items__c item : [
                SELECT Id, Warehouse__c, LastModifiedDate 
                FROM Warehouse_Product_Line_Items__c 
                WHERE Warehouse__c IN :warehouseProductIds 
                ORDER BY LastModifiedDate DESC
            ]) {
                if (!latestUsageMap.containsKey(item.Warehouse__c)) {
                    latestUsageMap.put(item.Warehouse__c, item);
                }
            }

            for (Id warehouseId : latestUsageMap.keySet()) {
                Warehouse_Product__c wp = new Warehouse_Product__c(
                    Id = warehouseId,
                    Last_Usage_Date__c = latestUsageMap.get(warehouseId).LastModifiedDate.date()
                );
                lastUsageDateUpdateList.add(wp);
            }

            if (!lastUsageDateUpdateList.isEmpty()) {
                update lastUsageDateUpdateList;
            }
        }
    }
}