public class UpdateDeliveryChallanQueueable implements Queueable {
    private List<Id> challanIds;

    public UpdateDeliveryChallanQueueable(List<Id> challanIds) {
        this.challanIds = challanIds;
    }

    public void execute(QueueableContext context) {
        if (challanIds == null || challanIds.isEmpty()) {
            System.debug('No Delivery Challan IDs provided.');
            return;
        }
        List<Delivery_Challan__c> dcsToUpdate = new List<Delivery_Challan__c>();
        List<Delivery_Challan__c> curDC = [select Id,isGRNCreated__c from Delivery_Challan__c where Id IN : challanIds ];
        for (Delivery_Challan__c toupdate : curDC) {
            dcsToUpdate.add(new Delivery_Challan__c(
                Id = toupdate.Id,
                isGRNCreated__c = true
            ));
        }

        if (!dcsToUpdate.isEmpty()) {
            try {
                update dcsToUpdate;
            } catch (Exception e) {
                System.debug('Failed to update Delivery Challans: ' + e.getMessage());
            }
        }
    }
}