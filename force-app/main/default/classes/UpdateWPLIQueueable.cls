public class UpdateWPLIQueueable implements Queueable{
    private List<Id> consignorWarehouseId;
    private Set<String> relevantSerials;

    public UpdateWPLIQueueable(List<Id> consignorWarehouseId, Set<String> relevantSerials) {
        this.consignorWarehouseId = consignorWarehouseId;
        this.relevantSerials = relevantSerials;
    }

    public void execute(QueueableContext context) {
        if (relevantSerials.isEmpty() || consignorWarehouseId.isEmpty()) {
            return;
        }
        List<Warehouse_Product_Line_Items__c> WPLIToUpdate = new List<Warehouse_Product_Line_Items__c>();
        List<Warehouse_Product_Line_Items__c> curRecord = [select Id, Status__c from 
                                                           Warehouse_Product_Line_Items__c where Connected_warehouse__c IN : consignorWarehouseId AND Serial_Number__c IN : relevantSerials ];
        for (Warehouse_Product_Line_Items__c toupdate : curRecord) {
            if(toupdate.Status__c == 'In Transit'){
                toupdate.Status__c = 'Delivered';
            }
            WPLIToUpdate.add(toupdate);
        }

        if (!WPLIToUpdate.isEmpty()) {
            try {
                update WPLIToUpdate;
            } catch (Exception e) {
                System.debug('Failed to update Delivery Challans: ' + e.getMessage());
            }
        }
    }
}