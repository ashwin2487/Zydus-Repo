public without sharing class RDCLITriggerHandler {
    
    public static void changeStatusInWarehouse(List<Delivery_Challan_Line_Item__c> lineItems) {
        if (lineItems == null || lineItems.isEmpty()) return;
        
        Id rdcRecordTypeId = Schema.SObjectType.Delivery_challan__c.getRecordTypeInfosByName().get('RDC').getRecordTypeId();
        
        Set<Id> deliveryChallanIds = new Set<Id>();
        for (Delivery_Challan_Line_Item__c item : lineItems) {
            if (item.Delivery_challan__c != null) {
                deliveryChallanIds.add(item.Delivery_challan__c);
            }
        }
        
        Map<Id, Delivery_challan__c> challanMap = new Map<Id, Delivery_challan__c>(
            [SELECT Id, RecordTypeId FROM Delivery_challan__c WHERE Id IN :deliveryChallanIds]
        );
        
        Set<String> serialNumbersToFind = new Set<String>();
        for (Delivery_Challan_Line_Item__c item : lineItems) {
            Delivery_challan__c parent = challanMap.get(item.Delivery_challan__c);
            if (parent != null && parent.RecordTypeId == rdcRecordTypeId && !String.isBlank(item.Serial_Number__c)) {
                serialNumbersToFind.add(item.Serial_Number__c.trim());
            }
        }
        
        if (serialNumbersToFind.isEmpty()) return;
        
        List<Warehouse_Product_Line_Items__c> matchedWarehouses = [SELECT Id, Serial_Number__c, Status__c, Connected_Warehouse__c, Connected_Warehouse__r.Name, 
                                                                   Warehouse__c, Warehouse__r.Zydus_Product__r.Material_Description__c
                                                                   FROM Warehouse_Product_Line_Items__c
                                                                   WHERE Serial_Number__c IN : serialNumbersToFind
                                                                   ALL ROWS
                                                                  ];
        
        List<Warehouse_Product_Line_Items__c> warehousesToUpdate = new List<Warehouse_Product_Line_Items__c>();
        for (Warehouse_Product_Line_Items__c wh : matchedWarehouses) {
            wh.Status__c = 'Material Returned';
            warehousesToUpdate.add(wh);
        }
        
        if (!warehousesToUpdate.isEmpty()) {
            try {
                update warehousesToUpdate;
                sendRSOGenerationEmail(warehousesToUpdate);
                
            } catch (Exception e) {
                System.debug('Error updating warehouse items: ' + e.getMessage());
            }
        }
    }
    
    private static void sendRSOGenerationEmail(List<Warehouse_Product_Line_Items__c> updatedWarehouses) {
        try {
            String systemAdminEmail = getSystemAdminEmail();
            
            if (String.isBlank(systemAdminEmail)) {
                System.debug('No system admin email found');
                return;
            }
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{systemAdminEmail});
            email.setSubject('RSO Generated - Warehouse Items Updated to Material Returned');
            
            String emailBody = buildEmailBody(updatedWarehouses);
            email.setHtmlBody(emailBody);
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            
            if (results[0].success) {
                System.debug('RSO generation email sent successfully');
            } else {
                System.debug('Error sending RSO generation email: ' + results[0].errors[0].message);
            }
            
        } catch (Exception e) {
            System.debug('Exception in sendRSOGenerationEmail: ' + e.getMessage());
        }
    }
    
    private static String getSystemAdminEmail() {
        try {
            User systemAdmin = [SELECT Email FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
            return systemAdmin.Email;
            
        } catch (Exception e) {
            System.debug('Error getting system admin email: ' + e.getMessage());
            return null;
        }
    }
    
    private static String buildEmailBody(List<Warehouse_Product_Line_Items__c> updatedWarehouses) {
        String emailBody = '<html><body style="font-family: Arial, sans-serif;">';
        emailBody += '<h2 style="color: #0066cc;">RSO Generation Notification</h2>';
        emailBody += '<p>Dear System Administrator,</p>';
        emailBody += '<p>An RSO (Return Sales Order) has been generated and RDC Processed, the following Warehouse Product Line Items have been updated to "Material Returned" status:</p>';
        
        emailBody += '<h3>Updated Items (' + updatedWarehouses.size() + '):</h3>';
        emailBody += '<table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse; width:100%; max-width:1000px;">';
        emailBody += '<tr style="background-color:#f2f2f2;">';
        emailBody += '<th style="text-align:left;">Serial Number</th>';
        emailBody += '<th style="text-align:left;">Connected Warehouse</th>';
        emailBody += '<th style="text-align:left;">Material Description</th>';
        emailBody += '<th style="text-align:left;">Record ID</th>';
        emailBody += '<th style="text-align:left;">Status</th>';
        emailBody += '</tr>';
        
        for (Warehouse_Product_Line_Items__c item : updatedWarehouses) {
            emailBody += '<tr>';
            emailBody += '<td>' + (item.Serial_Number__c != null ? item.Serial_Number__c : 'N/A') + '</td>';
            emailBody += '<td>' + (item.Connected_Warehouse__r != null && item.Connected_Warehouse__r.Name != null ? item.Connected_Warehouse__r.Name : 'N/A') + '</td>';
            emailBody += '<td>' + (item.Warehouse__r != null && item.Warehouse__r.Zydus_Product__r.Material_Description__c != null ? item.Warehouse__r.Zydus_Product__r.Material_Description__c : 'N/A') + '</td>';
            emailBody += '<td>' + item.Id + '</td>';
            emailBody += '<td>' + item.Status__c + '</td>';
            emailBody += '</tr>';
        }
        emailBody += '</table>';
        
        emailBody += '<br/><h3>Process Details:</h3>';
        emailBody += '<ul>';
        emailBody += '<li><strong>Process:</strong> RDC Line Item Trigger</li>';
        emailBody += '<li><strong>Timestamp:</strong> ' + DateTime.now().format() + '</li>';
        emailBody += '<li><strong>User:</strong> ' + UserInfo.getName() + ' (' + UserInfo.getUsername() + ')</li>';
        emailBody += '<li><strong>Total Items Updated:</strong> ' + updatedWarehouses.size() + '</li>';
        emailBody += '</ul>';
        
        emailBody += '<p>Please review the updated warehouse items and take necessary action if required.</p>';
        emailBody += '<p>Best regards,<br/>Salesforce System</p>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
}