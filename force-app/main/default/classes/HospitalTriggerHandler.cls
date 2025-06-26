public class HospitalTriggerHandler {
    
    public static void createContact(List<Hospital__c> newHospRec, Map<Id, Hospital__c> oldHospRec){
        List<Contact> contactsToCreate = new List<Contact>();
        List<Hospital__c> hospitalsToProcess = new List<Hospital__c>();
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        
        for (RecordType rt : [
            SELECT Id, Name FROM RecordType WHERE SObjectType = 'Contact'
        ]) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        
        Id hospRecordTypeId = recordTypeMap.get('Hospitals');
        if (hospRecordTypeId == null) {
            throw new AuraHandledException('Record Type "Hospitals" not found for Contact.');
        }
        
        for(Hospital__c hosp : newHospRec){
            Boolean wasInactiveBefore = oldHospRec != null && oldHospRec.containsKey(hosp.Id)
                ? oldHospRec.get(hosp.Id).Active__c == false
                : true;
            
            if (hosp.Active__c && wasInactiveBefore && hosp.L1_Approved__c && hosp.L2_Approved__c) {
                if (String.isBlank(hosp.Contact_Last_Name__c)) continue;
                
                Contact con = new Contact(
                    FirstName     = hosp.Contact_First_Name__c,
                    LastName      = hosp.Contact_Last_Name__c,
                    Email         = hosp.Contact_Email__c,
                    Phone         = hosp.Contact_Phone__c,
                    RecordTypeId  = hospRecordTypeId
                );
                
                contactsToCreate.add(con);
                hospitalsToProcess.add(hosp);
            }
        }
        Id hospitalWarehouseRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Warehouse__c' AND DeveloperName = 'Hospital' LIMIT 1].Id;
        if (!contactsToCreate.isEmpty()) {
            insert contactsToCreate;
            
            List<Warehouse__c> warehousesToCreate = new List<Warehouse__c>();
            for (Integer i = 0; i < hospitalsToProcess.size(); i++) {
                Hospital__c hosp = hospitalsToProcess[i];
                Contact createdContact = contactsToCreate[i];
                
                warehousesToCreate.add(new Warehouse__c(
                    Name			 = hosp.Name + ' Warehouse',
                    Hospital__c      = hosp.Id,
                    Contact__c       = createdContact.Id,
                    Address__c       = hosp.Shipping_Address__c	,
                    State__c         = hosp.Ship_State__c,
                    City__c          = hosp.Ship_City__c,
                    Country__c       = 'India',
                    ZipCode__c       = hosp.Ship_Pin__c,
                    RecordTypeid     = hospitalWarehouseRecordTypeId
                ));
            }
            
            insert warehousesToCreate;
            
            Map<Id, HospitalContactUpdater.ContactWarehouseWrapper> hospitalUpdateMap = new Map<Id, HospitalContactUpdater.ContactWarehouseWrapper>();
            Map<Id, Id> hospitalToWarehouseMap = new Map<Id, Id>();
            
            for (Integer i = 0; i < hospitalsToProcess.size(); i++) {
                Id hospId = hospitalsToProcess[i].Id;
                Id contactId = contactsToCreate[i].Id;
                Id warehouseId = warehousesToCreate[i].Id;
                
                hospitalUpdateMap.put(hospId, new HospitalContactUpdater.ContactWarehouseWrapper(contactId, warehouseId));
                hospitalToWarehouseMap.put(hospId, warehouseId);
            }
            
            List<Hospital_Product__c> hospitalProducts = [
                SELECT Id, Zydus_Product__c, Hospital__c 
                FROM Hospital_Product__c 
                WHERE Hospital__c IN :hospitalToWarehouseMap.keySet()
            ];
            
            List<Warehouse_Product__c> warehouseProductsToInsert = new List<Warehouse_Product__c>();
            for (Hospital_Product__c hp : hospitalProducts) {
                Id warehouseId = hospitalToWarehouseMap.get(hp.Hospital__c);
                if (warehouseId != null && hp.Zydus_Product__c != null) {
                    warehouseProductsToInsert.add(new Warehouse_Product__c(
                        Warehouse__c = warehouseId,
                        Zydus_Product__c   = hp.Zydus_Product__c
                    ));
                }
            }
            
            if (!warehouseProductsToInsert.isEmpty()) {
                insert warehouseProductsToInsert;
            }
            
            System.enqueueJob(new HospitalContactUpdater(hospitalUpdateMap));
        }
    }
}