public without sharing class InvoiceCreationTriggerHandler {
    
    public static void checkOutstandingCreditLimit(List<Invoice__c> newRec) {
        if (newRec.isEmpty()) return;
        Id hospitalRecordTypeId = Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName()
            .get('Hospital_Invoice')
            .getRecordTypeId();
        
        List<Invoice__c> dealerInvoices = new List<Invoice__c>();
        for (Invoice__c inv : newRec) {
            if (inv.RecordTypeId != hospitalRecordTypeId) {
                dealerInvoices.add(inv);
            }
        }
        
        if (dealerInvoices.isEmpty()) {
            return; 
        }
        
        Id currUserId = UserInfo.getUserId();
        List<Account> accounts = [SELECT Id, Available_Credit_Limit__c FROM Account WHERE Business_Owner__c = :currUserId LIMIT 1];
        
        if (accounts.isEmpty()) {
            return;
        }
        
        Account dealerAcc = accounts[0];
        
        List<Invoice__c> existingInvoices = [SELECT Id, Total_Pending_Amount__c FROM Invoice__c WHERE Consignee_Dealer__c = :dealerAcc.Id];
        
        Decimal totalPending = 0;
        for (Invoice__c inv : existingInvoices) {
            totalPending += inv.Total_Pending_Amount__c != null ? inv.Total_Pending_Amount__c : 0;
        }
        
        Set<Id> newInvoiceIds = new Set<Id>();
        for (Invoice__c inv : dealerInvoices) {
            if (inv.Id != null) newInvoiceIds.add(inv.Id);
        }
        
        Id creditNoteRTId = [SELECT Id FROM RecordType WHERE SobjectType = 'Credit_Note__c' AND DeveloperName = 'Invoice' LIMIT 1].Id;
        
        Map<Id, Decimal> creditNoteMap = new Map<Id, Decimal>();
        
        if (!newInvoiceIds.isEmpty()) {
            for (Credit_Note__c note : [
                SELECT Invoice__c, Amount__c
                FROM Credit_Note__c
                WHERE Invoice__c IN :newInvoiceIds AND RecordTypeId = :creditNoteRTId
            ]) {
                Decimal amount = note.Amount__c != null ? note.Amount__c : 0;
                creditNoteMap.put(note.Invoice__c,creditNoteMap.containsKey(note.Invoice__c) ? creditNoteMap.get(note.Invoice__c) + amount : amount);
            }
        }
        
        Decimal adjustedNew = 0;
        for (Invoice__c inv : dealerInvoices) {
            Decimal orig = inv.Total_Pending_Amount__c != null ? inv.Total_Pending_Amount__c : 0;
            Decimal credit = creditNoteMap.containsKey(inv.Id) ? creditNoteMap.get(inv.Id) : 0;
            adjustedNew += (orig - credit);
        }
        
        Decimal projected = totalPending + adjustedNew;
        
        if (projected > dealerAcc.Available_Credit_Limit__c) {
            for (Invoice__c inv : dealerInvoices) {
                inv.addError('⚠️ Cannot create invoice: Credit limit exceeded.');
            }
        }
    }
    public static void shareInvoices(List<Invoice__c> invoices) {
        Set<Id> accountIds = new Set<Id>();
        
        // Collect all Account IDs from Consignee and Consignor
        for (Invoice__c inv : invoices) {
            if (inv.Consignee_Dealer__c != null) accountIds.add(inv.Consignee_Dealer__c);
            if (inv.Consignor_Dealer__c != null) accountIds.add(inv.Consignor_Dealer__c);
        }
        
        // Query Business Owner from Accounts
        Map<Id, Id> accountToOwner = new Map<Id, Id>();
        for (Account acc : [SELECT Id, Business_owner__c FROM Account WHERE Id IN :accountIds]) {
            if (acc.Business_owner__c != null) {
                accountToOwner.put(acc.Id, acc.Business_owner__c);
            }
        }
        
        List<Invoice__Share> shares = new List<Invoice__Share>();
        
        // Create shares for each Invoice
        for (Invoice__c inv : invoices) {
            Set<Id> sharedUsers = new Set<Id>();
            
            if (accountToOwner.containsKey(inv.Consignee_Dealer__c)) {
                sharedUsers.add(accountToOwner.get(inv.Consignee_Dealer__c));
            }
            
            if (accountToOwner.containsKey(inv.Consignor_Dealer__c)) {
                sharedUsers.add(accountToOwner.get(inv.Consignor_Dealer__c));
            }
            
            for (Id userId : sharedUsers) {
                Invoice__Share share = new Invoice__Share();
                share.ParentId = inv.Id;
                share.UserOrGroupId = userId;
                share.AccessLevel = 'Read';
                share.RowCause = Schema.Invoice__Share.RowCause.Manual;
                shares.add(share);
            }
        }
        
        if (!shares.isEmpty()) {
            Database.insert(shares, false);
        }
    }
}