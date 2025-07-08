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
        Set<Id> WhIds=new Set<Id>();
        List<Hospital__c> hospitalsToUpdate = [
            SELECT Id FROM Hospital__c WHERE Id IN :hospUpdateMap.keySet()
        ];
        
        Set<Id> hospIds=new Set<Id>();
        
        for(Hospital__c hosp: hospitalsToUpdate){
            hospIds.add(hosp.Id);
        }
        
        Warehouse__c warehouses=[SELECT Id, Contact__c FROM Warehouse__c WHERE Hospital__c IN :hospIds LIMIT 1];
        
        for (Hospital__c hosp : hospitalsToUpdate) {
            ContactWarehouseWrapper wrapper = hospUpdateMap.get(hosp.Id);
            if (wrapper != null) {
                hosp.Contact__c = wrapper.contactId;
                warehouses.Contact__c = wrapper.contactId;
            }
        }
        
        if(warehouses!=null){
            update warehouses;
        }
      
        if (!hospitalsToUpdate.isEmpty()) {
            update hospitalsToUpdate;
        }
        if(!hospUpdateMap.isEmpty()){
             System.enqueueJob(new FirstOrderCreationQueueHospital(new List<Id>(hospUpdateMap.keySet())));
        }
    }
}