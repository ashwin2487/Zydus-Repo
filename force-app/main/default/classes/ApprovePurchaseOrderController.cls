public with sharing class ApprovePurchaseOrderController {
    @AuraEnabled
    public static void approvePurchaseOrder(Id recordId) {
        User currentUser = [
            SELECT Id, UserRole.Name 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String userRole = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        
        if (!(userRole == 'Super Distributor' || userRole == 'Distributor' || userRole == 'Sub Distributor')) {
            throw new AuraHandledException('Access denied: Only Super Distributor, Distributor, or Sub Distributor can approve Purchase Orders.');
        }
        
        Purchase_Order__c po = [
            SELECT Id,Name, StageName__c,Account__r.Business_Owner__r.Name, Account__r.Business_Owner__c, Supplier_Distributor__r.Business_Owner__c,
            Account__r.Name,Supplier_Distributor__r.Business_Owner__r.Email,Supplier_Distributor__r.Name
            FROM Purchase_Order__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        if (po.Account__r.Business_Owner__c != UserInfo.getUserId()) {
            throw new AuraHandledException('Access denied: Only the Business Owner can approve this Purchase Order.');
        }
        
        if (po.StageName__c != 'Draft Purchase Order') {
            throw new AuraHandledException('Only Purchase Orders in Draft stage can be approved.');
        }
        
        po.StageName__c = 'Approve Purchase Order';
        update po;
        system.debug('email business owner is '+po.Supplier_Distributor__r.Business_Owner__r.Email);
        String body='Purchase Order '+ po.Name + ' has been successfully approved by '+ po.Account__r.Business_Owner__r.Name +'. Please proceed with the creation of the associated Sales Order at your convenience.';
        NotificationService.notifyUsers(
            new Set<String>{po.Supplier_Distributor__r.Business_Owner__c}, 
            po.Id, 
            'New PO Generated', 
            body
        );
      /*  if(userRole != 'Super Distributor'){
                    String emailBody = 'Purchase Order "' + po.Name + '" for Account "' + po.Account__r.Name + 
            '" has been successfully approved by ' + po.Account__r.Business_Owner__r.Name + 
            '.\n\nDistributor: ' + po.Supplier_Distributor__r.Name + 
            '\n\nPlease proceed with the creation of the associated Sales Order at your convenience.';
        
        NotificationService.sendEmail(
            new List<String>{po.Supplier_Distributor__r.Business_Owner__r.Email},
            'New PO Approved',
            emailBody
        );
        }*/
    }
}