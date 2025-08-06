public without sharing class warehouseTriggerHandler {
    public static void ShareHospitalWarehouse(List<Warehouse__c> newRecords) {
        Map<String, Id> rtMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Warehouse__c']) {
            rtMap.put(rt.Name, rt.Id);
        }
        Id hospitalRTId = rtMap.get('Hospital');
        if (hospitalRTId == null) {
            return;
        }

        List<Warehouse__c> hospitalWarehouses = new List<Warehouse__c>();
        Set<Id> hospitalIds = new Set<Id>();

        for (Warehouse__c wh : newRecords) {
            if (wh.RecordTypeId == hospitalRTId && wh.Hospital__c != null) {
                hospitalWarehouses.add(wh);
                hospitalIds.add(wh.Hospital__c);
            }
        }

        if (hospitalWarehouses.isEmpty()) {
            return;
        }

        Map<Id, List<Warehouse__c>> hospitalToWarehousesMap = new Map<Id, List<Warehouse__c>>();
        for (Warehouse__c wh : [SELECT Id, Hospital__c, RecordTypeId 
                                FROM Warehouse__c 
                                WHERE Hospital__c IN :hospitalIds AND RecordTypeId = :hospitalRTId
                               ]) {
                                   if (!hospitalToWarehousesMap.containsKey(wh.Hospital__c)) {
                                       hospitalToWarehousesMap.put(wh.Hospital__c, new List<Warehouse__c>());
                                   }
                                   hospitalToWarehousesMap.get(wh.Hospital__c).add(wh);
                               }

        List<Account_Hospital__c> connectedAccounts = [SELECT Id, Account__c, Account__r.Business_Owner__c, Hospital__c
                                                       FROM Account_Hospital__c
                                                       WHERE Hospital__c IN :hospitalIds
                                                      ];

        List<Warehouse__Share> warehouseSharesToInsert = new List<Warehouse__Share>();

        for (Account_Hospital__c ah : connectedAccounts) {
            Id businessOwnerId = ah.Account__r?.Business_Owner__c;
            if (businessOwnerId == null) {
                continue;
            }

            List<Warehouse__c> warehousesForHospital = hospitalToWarehousesMap.get(ah.Hospital__c);
            if (warehousesForHospital == null) {
                continue;
            }

            for (Warehouse__c wh : warehousesForHospital) {
                warehouseSharesToInsert.add(new Warehouse__Share(
                    ParentId = wh.Id,
                    UserOrGroupId = businessOwnerId,
                    AccessLevel = 'Edit',
                    RowCause = Schema.Warehouse__Share.RowCause.Manual
                ));
            }
        }

        if (!warehouseSharesToInsert.isEmpty()) {
            try {
                insert warehouseSharesToInsert;
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'Error creating Warehouse Share records: ' + e.getMessage());
            }
        }
    }
}