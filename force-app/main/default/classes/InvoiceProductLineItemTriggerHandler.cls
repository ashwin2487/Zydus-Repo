public class InvoiceProductLineItemTriggerHandler {
    public static void createCreditNote(List<Invoice_Product_Line_Item__c> newRecords){
        Set<Id> productIds = new Set<Id>();
        Set<Id> invoiceIds = new Set<Id>();
        
        for (Invoice_Product_Line_Item__c item : newRecords) {
            if (item.Zydus_Product__c != null) {
                productIds.add(item.Zydus_Product__c);
            }
            if (item.Invoice__c != null) {
                invoiceIds.add(item.Invoice__c);
            }
        }
        
        if (productIds.isEmpty() || invoiceIds.isEmpty()) {
            return;
        }
        
        Id userId = UserInfo.getUserId();
        Account userAccount = [
            SELECT Id, Zydus_Price_Book__c
            FROM Account
            WHERE Business_Owner__c = :userId
            LIMIT 1
        ];
        
        if (userAccount.Zydus_Price_Book__c == null) {
            return;
        }
        
        Map<Id, Decimal> invoiceToCreditAmountMap = new Map<Id, Decimal>();
        
        Map<Id, Decimal> productToCreditAmount = new Map<Id, Decimal>();
        
        for (Zydus_Price_Book_Entry__c pbe : [
            SELECT Zydus_Product__c, Credit_Note_Amount__c
            FROM Zydus_Price_Book_Entry__c
            WHERE Zydus_Product__c IN :productIds
            AND Zydus_Price_Book__c = :userAccount.Zydus_Price_Book__c
        ]) {
            productToCreditAmount.put(pbe.Zydus_Product__c, pbe.Credit_Note_Amount__c);
        }
        
        for (Invoice_Product_Line_Item__c item : newRecords) {
            if (item.Zydus_Product__c != null && item.Invoice__c != null) {
                Decimal creditAmt = productToCreditAmount.get(item.Zydus_Product__c);
                if (creditAmt != null) {
                    if (!invoiceToCreditAmountMap.containsKey(item.Invoice__c)) {
                        invoiceToCreditAmountMap.put(item.Invoice__c, 0);
                    }
                    invoiceToCreditAmountMap.put(item.Invoice__c, invoiceToCreditAmountMap.get(item.Invoice__c) + creditAmt);
                }
            }
        }
        
        
        List<Credit_Note__c> notesToInsert = new List<Credit_Note__c>();
        Id recordTypeId =[select Id from RecordType where SobjectType = 'Credit_Note__c' and DeveloperName = 'Invoice'].Id;
        // Fetch all Invoice records in one query
        Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>(
            [SELECT Id, Delivery_Challan__r.Supply_Order__c , Hospital__c
             FROM Invoice__c 
             WHERE Id IN :invoiceToCreditAmountMap.keySet()]
        );
        
        for (Id invoiceId : invoiceToCreditAmountMap.keySet()) {        
            Invoice__c inv = invoiceMap.get(invoiceId);
            
            Credit_Note__c note = new Credit_Note__c();
            note.Account__c = userAccount.Id;
            note.Date__c = Date.today();
            note.Amount__c = invoiceToCreditAmountMap.get(invoiceId);
            note.Invoice__c = invoiceId;
            note.Hospital__c = inv.Hospital__c != null ? inv.Hospital__c : null;
            note.RecordTypeId = recordTypeId;
            note.Is_used__c= true;
            
            if (inv != null && inv.Delivery_Challan__r != null) {
                note.Supply_Order__c = inv.Delivery_Challan__r.Supply_Order__c;
            }
            
            notesToInsert.add(note);
        }
        
        if (!notesToInsert.isEmpty()) {
            insert notesToInsert;
        }
    }
    
    public static void preventInvoiceCreationIfProductExpired(List<Invoice_Product_Line_Item__c> newRecords) {
        Set<Id> warehouseLineItemIds = new Set<Id>();
        for (Invoice_Product_Line_Item__c ipli : newRecords) {
            if (ipli.Warehouse_Product_Line_Item__c != null) {
                warehouseLineItemIds.add(ipli.Warehouse_Product_Line_Item__c);
            }
        }
        
        Map<Id, Boolean> warehouseItemToExpiredFlag = new Map<Id, Boolean>();
        if (!warehouseLineItemIds.isEmpty()) {
            
            for (Warehouse_Product_Line_Items__c wpli : [SELECT Id, Is_Expired__c FROM Warehouse_Product_Line_Items__c WHERE Id IN :warehouseLineItemIds]) {
                warehouseItemToExpiredFlag.put(wpli.Id, wpli.Is_Expired__c);
            }
            
        }
        
        for (Invoice_Product_Line_Item__c ipli : newRecords) {
            if (ipli.Warehouse_Product_Line_Item__c != null &&
                warehouseItemToExpiredFlag.containsKey(ipli.Warehouse_Product_Line_Item__c) &&
                warehouseItemToExpiredFlag.get(ipli.Warehouse_Product_Line_Item__c) == true
               ) {
                   ipli.addError('❌ Cannot create invoice: Product is expired in the selected warehouse.');
               }
        }
    }
    
}