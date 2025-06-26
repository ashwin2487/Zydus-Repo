public without sharing class AutoGrnForHospitalOnDcHandler {
    public static void createGRNs(List<Delivery_Challan_Line_Item__c> newDCLineItems) {
        if (newDCLineItems == null || newDCLineItems.isEmpty()) return;
        
        Id newDCId = [SELECT Delivery_Challan__c FROM Delivery_Challan_Line_Item__c WHERE Id = :newDCLineItems[0].Id].Delivery_Challan__c;
        
        Delivery_Challan__c dc = [
            SELECT Id, Name ,Consignee_Hospital__c, Consignor_Distributor__c, RecordType.DeveloperName, DC_Generated_Date__c,
            (SELECT Id, Zydus_Product__c, Expiry_Date__c, Serial_Number__c, Batch_Number__c,
             Manufacturing_Date__c, Unit_Price__c
             FROM Delivery_Challan_Line_Items__r)
            FROM Delivery_Challan__c
            WHERE Id = :newDCId
        ];
        
        if (dc == null || dc.RecordType.DeveloperName != 'HDC') return;
        
        // Get warehouse of the consignee hospital
        Warehouse__c consigneeWarehouse = [SELECT Id FROM Warehouse__c WHERE Hospital__c = :dc.Consignee_Hospital__c LIMIT 1];
        
        if (consigneeWarehouse == null) return;
        
        Id consigneeWarehouseId = consigneeWarehouse.Id;
        
        // Ensure Warehouse_Product__c exists
        Set<Id> productIds = new Set<Id>();
        for (Delivery_Challan_Line_Item__c item : dc.Delivery_Challan_Line_Items__r) {
            productIds.add(item.Zydus_Product__c);
        }
        
        Map<String, Warehouse_Product__c> productWarehouseMap = new Map<String, Warehouse_Product__c>();
        for (Warehouse_Product__c wp : [
            SELECT Id, Zydus_Product__c, Warehouse__c
            FROM Warehouse_Product__c
            WHERE Zydus_Product__c IN :productIds AND Warehouse__c = :consigneeWarehouseId
        ]) {
            productWarehouseMap.put(wp.Zydus_Product__c + '-' + consigneeWarehouseId, wp);
        }
        
        List<Warehouse_Product__c> toInsertWPs = new List<Warehouse_Product__c>();
        for (Id productId : productIds) {
            String key = productId + '-' + consigneeWarehouseId;
            if (!productWarehouseMap.containsKey(key)) {
                Warehouse_Product__c newWp = new Warehouse_Product__c(
                    Zydus_Product__c = productId,
                    Warehouse__c = consigneeWarehouseId
                );
                toInsertWPs.add(newWp);
                productWarehouseMap.put(key, newWp);
            }
        }
        if (!toInsertWPs.isEmpty()) insert toInsertWPs;
        
        // Create GRN
        Id rtID = Schema.SObjectType.GRN__c.getRecordTypeInfosByDeveloperName().get('Hospital_GRN').getRecordTypeId();
        
        GRN__c grn = new GRN__c(
            Delivery_Challan__c = dc.Id,
            GRN_Date__c = System.today(),
            RecordTypeId = rtID
        );
        insert grn;
        
        // Create Line Items
        List<Warehouse_Product_Line_Items__c> toInsertLineItems = new List<Warehouse_Product_Line_Items__c>();
        Set<String> relevantSerials = new Set<String>();
        Integer acceptedProducts = 0;
        
        for (Delivery_Challan_Line_Item__c dcItem : dc.Delivery_Challan_Line_Items__r) {
            String key = dcItem.Zydus_Product__c + '-' + consigneeWarehouseId;
            Warehouse_Product__c wp = productWarehouseMap.get(key);
            
            Warehouse_Product_Line_Items__c lineItem = new Warehouse_Product_Line_Items__c(
                GRN__c = grn.Id,
                Warehouse__c = wp.Id,
                Connected_Warehouse__c = consigneeWarehouseId,
                Serial_Number__c = dcItem.Serial_Number__c,
                Batch_Number__c = dcItem.Batch_Number__c,
                Supplied_Date__c = dc.DC_Generated_Date__c,
                Manufactured_Date__c = dcItem.Manufacturing_Date__c,
                Expiry_Date__c = dcItem.Expiry_Date__c,
                Condition__c = 'Good',
                Status__c = 'Free',
                Delivery_Challan_Line_Item__c = dcItem.Id,
                Unit_Price__c = dcItem.Unit_Price__c
            );
            
            if (lineItem.Serial_Number__c != null) {
                relevantSerials.add(lineItem.Serial_Number__c);
            }
            
            acceptedProducts++;
            toInsertLineItems.add(lineItem);
        }
        
        if (!toInsertLineItems.isEmpty()) insert toInsertLineItems;
        
        grn.Accepted_Products__c = acceptedProducts;
        grn.Rejected_Products__c = 0;
        update grn;
        
        // Update line item status in consignor's warehouse
        Id consignorWarehouseId = [SELECT Id FROM Warehouse__c WHERE Account__c = :dc.Consignor_Distributor__c LIMIT 1].Id;        
        
        // Send notifications
        Account consignor = [SELECT Id, Business_Owner__c, Business_Owner__r.Email FROM Account WHERE Id = :dc.Consignor_Distributor__c LIMIT 1];
        Hospital__c hospital = [SELECT Contact_Email__c, CC_Email_Address__c FROM Hospital__c WHERE Id = :dc.Consignee_Hospital__c LIMIT 1];
        
        Set<String> userIds = new Set<String>();
        List<String> emailAddresses = new List<String>();
        
        if (consignor != null && consignor.Business_Owner__c != null) {
            userIds.add(consignor.Business_Owner__c);
            if (consignor.Business_Owner__r.Email != null) {
                emailAddresses.add(consignor.Business_Owner__r.Email);
            }
        }
        
        if (hospital != null) {
            if (String.isNotBlank(hospital.Contact_Email__c))
                emailAddresses.add(hospital.Contact_Email__c);
            if (String.isNotBlank(hospital.CC_Email_Address__c))
                emailAddresses.add(hospital.CC_Email_Address__c);
        }
        
        String subject = 'New GRN Created: ' + grn.Name;
        String body = 'Dear User,\n\n'
            + 'A new GRN (Goods Receipt Note) "' + grn.Name + '" has been successfully created.\n\n'
            + 'Details:\n'
            + '- Accepted Quantity: ' + grn.Accepted_Products__c + '\n'
            + '- Rejected Quantity: ' + grn.Rejected_Products__c + '\n'
            + '- Against Delivery Challan: ' + dc.Name + '\n\n'
            + 'Please review the GRN for further actions.\n\n'
            + 'Best regards,\nZydus DMS';
        
        if (!userIds.isEmpty()) NotificationService.notifyUsers(userIds, grn.Id, subject, body);
        if (!emailAddresses.isEmpty()) NotificationService.sendEmail(emailAddresses, subject, body);
        System.enqueueJob(new UpdateDeliveryChallanQueueable(new List<Id>{ dc.Id }));
        System.enqueueJob(new UpdateWPLIQueueable(new List<Id>{consignorWarehouseId}, relevantSerials));
    }
}