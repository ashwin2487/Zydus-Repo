public with sharing class InvoiceController {
    @AuraEnabled(cacheable=true)
    public static InvoiceWrapper getInvoiceDetails(Id recordId) {
        // Return empty wrapper if recordId is null
        if (recordId == null) {
            return new InvoiceWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
        }
        
        try {
            List<Invoice__c> invoices = [
                SELECT 
                    Id, CATH_Number__c, Comment__c, Comment_Remark__c, 
                    Consignee_Dealer__c, Hospital__c, Consignor_Dealer__c, Date_of_Implant__c, Delivery_Challan__c,Doctor_Name__c,
                	Invoice_Closed__c, InvoiceDate__c, Name, InvoiceNumber__c, Invoice_Type__c, IP_Number__c, is_Invoiced_By_Parent__c, OwnerId,
                	Patient_Age__c, Patient_First_Name__c, Patient_Gender__c, Patient_Last_Name__c,
                    Patient_Name__c, Payment_Mode__c, Payment_Status__c, RecordTypeId, Status__c,
                    Total_Amount__c, Total_CGST__c,Total_Collected_Amount__c, Total_IGST__c, Total_Pending_Amount__c, Total_SGST__c,  Invoice_Due_Date__c,
                
                
                    Consignor_Dealer__r.Name,
                    Consignor_Dealer__r.Address__c,
                    Consignor_Dealer__r.City__c,
                    Consignor_Dealer__r.State__c,
                    Consignor_Dealer__r.Account_Pin_Code__c,
                    Consignor_Dealer__r.Drug_Licence_Number__c,
                    Consignor_Dealer__r.GST_Number__c,
                    Consignor_Dealer__r.PAN_Number__c,
                    Consignee_Dealer__r.Name,
                    Consignee_Dealer__r.Address__c,
                    Consignee_Dealer__r.State__c,
                    Consignee_Dealer__r.City__c,
                    Consignee_Dealer__r.Account_Pin_Code__c,
                    Consignee_Dealer__r.Drug_Licence_Number__c,
                    Consignee_Dealer__r.PAN_Number__c,
                    Consignee_Dealer__r.GST_Number__c,
                    Consignee_Dealer__r.Payment_Term__c,
                    
                    (
                        SELECT Id, 
                               Scheme__c,
                               SGST__c,
                               IGST__c, 
                               CGST__c,
                        	   	Bill_Discount_Amount__c,
                        Before_Tax_Amount__c,
                               Net_Amount__c,
                               Unit_Price__c,
                               Serial_Number__c,
                               Batch_Number__c,
                               Manufacture_Date__c,
                               Expiry_Date__c,
                               HSN__c,
                               Zydus_Product__c,
                               Zydus_Product__r.Name,
                               Zydus_Product__r.Length__c,
                               Zydus_Product__r.Diameter__c,
                               Zydus_Product__r.Material_Description__c
                        FROM Invoice_Product_Line_Items__r
                        ORDER BY Serial_Number__c ASC NULLS LAST
                    )
                FROM Invoice__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            // If no invoice found, return empty wrapper
            if (invoices.isEmpty()) {
                return new InvoiceWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
            }
            
            Invoice__c invoice = invoices[0];
            
            // Initialize warehouse lists
            List<Warehouse__c> consignorWarehouses = new List<Warehouse__c>();
            List<Warehouse__c> consigneeWarehouses = new List<Warehouse__c>();
            
            // Fetch consignor warehouses only if Consignor_Dealer__c is not null
            if (invoice.Consignor_Dealer__c != null) {
                try {
                    consignorWarehouses = [
                        SELECT Id, Name, Address__c, City__c, State__c, ZipCode__c 
                        FROM Warehouse__c 
                        WHERE Account__c = :invoice.Consignor_Dealer__c
                        ORDER BY Name ASC NULLS LAST
                    ];
                } catch (Exception e) {
                    System.debug('Error fetching consignor warehouses: ' + e.getMessage());
                    consignorWarehouses = new List<Warehouse__c>();
                }
            }
            
            // Fetch consignee warehouses only if Consignee_Dealer__c is not null
            if (invoice.Consignee_Dealer__c != null) {
                try {
                    consigneeWarehouses = [
                        SELECT Id, Name, Address__c, City__c, State__c, ZipCode__c 
                        FROM Warehouse__c 
                        WHERE Account__c = :invoice.Consignee_Dealer__c
                        ORDER BY Name ASC NULLS LAST
                    ];
                } catch (Exception e) {
                    System.debug('Error fetching consignee warehouses: ' + e.getMessage());
                    consigneeWarehouses = new List<Warehouse__c>();
                }
            }
            
            return new InvoiceWrapper(invoice, consignorWarehouses, consigneeWarehouses);
            
        } catch (Exception e) {
            System.debug('Error in getInvoiceDetails: ' + e.getMessage());
            // Return empty wrapper in case of any exception
            return new InvoiceWrapper(null, new List<Warehouse__c>(), new List<Warehouse__c>());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getRecordType(Id recordId){
        if (recordId == null) {
            return '';
        }
        
        try {
            // Get the SObject type from the record ID
            String sObjectType = recordId.getSObjectType().getDescribe().getName();
            
            // Dynamic SOQL to get RecordTypeId from the record
            String query = 'SELECT RecordTypeId FROM ' + sObjectType + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(query);
            
            if (records.isEmpty() || records[0].get('RecordTypeId') == null) {
                return '';
            }
            
            Id recordTypeId = (Id) records[0].get('RecordTypeId');
            
            // Query RecordType to get the name
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
    
    public class InvoiceWrapper {
        @AuraEnabled public Invoice__c invoice;
        @AuraEnabled public List<Warehouse__c> consignorWarehouses;
        @AuraEnabled public List<Warehouse__c> consigneeWarehouses;
        
        public InvoiceWrapper(Invoice__c inv, List<Warehouse__c> consignorWh, List<Warehouse__c> consigneeWh) {
            this.invoice = inv;
            this.consignorWarehouses = consignorWh != null ? consignorWh : new List<Warehouse__c>();
            this.consigneeWarehouses = consigneeWh != null ? consigneeWh : new List<Warehouse__c>();
        }
        
        // Utility methods to check if data exists
        @AuraEnabled 
        public Boolean getHasInvoice() {
            return this.invoice != null;
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
        public Boolean getHasLineItems() {
            return this.invoice != null && 
                   this.invoice.Invoice_Product_Line_Items__r != null && 
                   !this.invoice.Invoice_Product_Line_Items__r.isEmpty();
        }
        
        @AuraEnabled 
        public Integer getLineItemCount() {
            if (this.invoice != null && this.invoice.Invoice_Product_Line_Items__r != null) {
                return this.invoice.Invoice_Product_Line_Items__r.size();
            }
            return 0;
        }
    }
}