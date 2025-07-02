public with sharing class DeliveryChallanController {
    @AuraEnabled(cacheable=true)
    public static DeliveryChallanWrapper getDeliveryChallanDetails(Id recordId) {
        if (recordId == null) {
            return new DeliveryChallanWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
        }
        
        try {
            List<Delivery_Challan__c> deliveryChallans = [
                SELECT 
                    Id, Name, DC_Generated_Date__c, isGRNCreated__c, Net_Amount__c,
                    Total_CGST__c, Total_IGST__c, Total_Quantity__c, Total_SGST__c,
                    Supply_Order__c, CreatedById, LastModifiedById, OwnerId, RecordTypeId,
                    Consignee_Distributor__c, Consignee_Hospital__c, Consignor_Distributor__c,
                    Courier_Docket_No__c, Courier_Name__c, 	Comment__c,
                    
                    Consignee_Hospital__r.Name,
                    Consignee_Hospital__r.Address__c,
                    Consignee_Hospital__r.City__c,
                    Consignee_Hospital__r.State__c,
                    Consignee_Hospital__r.Hospital_Pin_Code__c,
                    Consignee_Hospital__r.DL_no__c,
                    Consignee_Hospital__r.GST_Number__c,
                    Consignee_Hospital__r.PAN_Number__c,
                    
                    Consignee_Distributor__r.Name,
                    Consignee_Distributor__r.Address__c,
                    Consignee_Distributor__r.State__c,
                    Consignee_Distributor__r.City__c,
                    Consignee_Distributor__r.Account_Pin_Code__c,
                    Consignee_Distributor__r.Drug_Licence_Number__c,
                    Consignee_Distributor__r.PAN_Number__c,
                    Consignee_Distributor__r.GST_Number__c,
                
                	Consignor_Distributor__r.Name,
                    Consignor_Distributor__r.Address__c,
                    Consignor_Distributor__r.State__c,
                    Consignor_Distributor__r.City__c,
                    Consignor_Distributor__r.Account_Pin_Code__c,
                    Consignor_Distributor__r.Drug_Licence_Number__c,
                    Consignor_Distributor__r.PAN_Number__c,
                    Consignor_Distributor__r.GST_Number__c,
                
                	
                    
                    Supply_Order__r.Name,
                    Supply_Order__r.createdDate,
                    
                    (
                        SELECT Id, Name, Zydus_Product__c, 
                               Zydus_Product__r.Name, 
                               Zydus_Product__r.Diameter__c, 
                               Zydus_Product__r.Length__c,
                               Zydus_Product__r.Material_Description__c,
                               
                               (
                                   SELECT Id, Name, Warehouse__c,
                                          Warehouse__r.Address__c,
                                          Warehouse__r.City__c,
                                          Warehouse__r.State__c,
                                          Warehouse__r.ZipCode__c,
                                          Serial_Number__c,
                                          Batch_Number__c,
                                          Manufacturing_Date__c,
                                          Expiry_Date__c,
                                          HSN_Code__r.Name,
                                          Unit_Price__c,
                                          CGST__c,
                                          IGST__c,
                                          SGST__c,
                                          Net_Amount__c
                                   FROM Delivery_Challan_Line_Items__r
                               )
                        FROM DC_Products__r
                    )
                FROM Delivery_Challan__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (deliveryChallans.isEmpty()) {
                return new DeliveryChallanWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
            }
            
            Delivery_Challan__c deliveryChallan = deliveryChallans[0];
            
            List<Warehouse__c> consignorWarehouses = new List<Warehouse__c>();
            List<Warehouse__c> consigneeWarehouses = new List<Warehouse__c>();
            
            if (deliveryChallan.Consignor_Distributor__c != null) {
                try {
                    consignorWarehouses = [
                        SELECT Id, Name, Address__c, City__c, State__c, ZipCode__c 
                        FROM Warehouse__c 
                        WHERE Account__c = :deliveryChallan.Consignor_Distributor__c
                        ORDER BY Name ASC NULLS LAST
                    ];
                } catch (Exception e) {
                    System.debug('Error fetching consignor warehouses: ' + e.getMessage());
                    consignorWarehouses = new List<Warehouse__c>();
                }
            }
            
            if (deliveryChallan.Consignee_Distributor__c != null) {
                try {
                    consigneeWarehouses = [
                        SELECT Id, Name, Address__c, City__c, State__c, ZipCode__c 
                        FROM Warehouse__c 
                        WHERE Account__c = :deliveryChallan.Consignee_Distributor__c
                        ORDER BY Name ASC NULLS LAST
                    ];
                } catch (Exception e) {
                    System.debug('Error fetching consignee warehouses: ' + e.getMessage());
                    consigneeWarehouses = new List<Warehouse__c>();
                }
            }
            
            return new DeliveryChallanWrapper(deliveryChallan, consignorWarehouses, consigneeWarehouses);
            
        } catch (Exception e) {
            System.debug('Error in getDeliveryChallanDetails: ' + e.getMessage());
            return new DeliveryChallanWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getRecordType(Id recordId){
        if (recordId == null) {
            return '';
        }
        
        try {
            String sObjectType = recordId.getSObjectType().getDescribe().getName();
            
            String query = 'SELECT RecordTypeId FROM ' + sObjectType + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(query);
            
            if (records.isEmpty() || records[0].get('RecordTypeId') == null) {
                return '';
            }
            
            Id recordTypeId = (Id) records[0].get('RecordTypeId');
            
            List<RecordType> recordTypes = [SELECT Name FROM RecordType WHERE Id = :recordTypeId LIMIT 1];
            
            if (recordTypes.isEmpty()) {
                return '';
            }
            
            return String.isBlank(recordTypes[0].Name) ? '' : recordTypes[0].Name;
            
        } catch (Exception e) {
            System.debug('Error getting RecordType name: ' + e.getMessage());
            return '';
        }
    }
    
    public class DeliveryChallanWrapper {
        @AuraEnabled public Delivery_Challan__c deliveryChallan;
        @AuraEnabled public List<Warehouse__c> consignorWarehouses;
        @AuraEnabled public List<Warehouse__c> consigneeWarehouses;
        
        public DeliveryChallanWrapper(Delivery_Challan__c dc, List<Warehouse__c> consignorWh, List<Warehouse__c> consigneeWh) {
            this.deliveryChallan = dc;
            this.consignorWarehouses = consignorWh != null ? consignorWh : new List<Warehouse__c>();
            this.consigneeWarehouses = consigneeWh != null ? consigneeWh : new List<Warehouse__c>();
        }
        
        @AuraEnabled 
        public Boolean getHasDeliveryChallan() {
            return this.deliveryChallan != null;
        }
        
        @AuraEnabled 
        public Boolean getHasConsignorWarehouses() {
            return this.consignorWarehouses != null && !this.consignorWarehouses.isEmpty();
        }
        
        @AuraEnabled 
        public Boolean getHasConsigneeWarehouses() {
            return this.consigneeWarehouses != null && !this.consigneeWarehouses.isEmpty();
        }
        
        @AuraEnabled 
        public Boolean getHasDCProducts() {
            return this.deliveryChallan != null && 
                   this.deliveryChallan.DC_Products__r != null && 
                   !this.deliveryChallan.DC_Products__r.isEmpty();
        }
        
        @AuraEnabled 
        public Integer getDCProductCount() {
            if (this.deliveryChallan != null && this.deliveryChallan.DC_Products__r != null) {
                return this.deliveryChallan.DC_Products__r.size();
            }
            return 0;
        }
    }
}