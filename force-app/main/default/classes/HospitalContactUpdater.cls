public class HospitalContactUpdater implements Queueable {
    
    public class ContactWarehouseWrapper {
        public Id contactId;
        public Id warehouseId;
        
        public ContactWarehouseWrapper(Id contactId, Id warehouseId) {
            this.contactId = contactId;
            this.warehouseId = warehouseId;
        }
    }
    
    private Map<Id, ContactWarehouseWrapper> hospUpdateMap;
    
    public HospitalContactUpdater(Map<Id, ContactWarehouseWrapper> hospUpdateMap) {
        this.hospUpdateMap = hospUpdateMap;
    }
    
    public void execute(QueueableContext context) {
        List<Hospital__c> hospitalsToUpdate = [
            SELECT Id FROM Hospital__c WHERE Id IN :hospUpdateMap.keySet()
        ];
        
        for (Hospital__c hosp : hospitalsToUpdate) {
            ContactWarehouseWrapper wrapper = hospUpdateMap.get(hosp.Id);
            if (wrapper != null) {
                hosp.Contact__c = wrapper.contactId;
                hosp.Warehouse__c = wrapper.warehouseId;
            }
        }
        
        if (!hospitalsToUpdate.isEmpty()) {
            update hospitalsToUpdate;
        }
        if(!hospUpdateMap.isEmpty()){
             System.enqueueJob(new FirstOrderCreationQueueHospital(new List<Id>(hospUpdateMap.keySet())));
        }
    }
}