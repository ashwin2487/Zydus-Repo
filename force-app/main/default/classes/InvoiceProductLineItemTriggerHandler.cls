public class InvoiceProductLineItemTriggerHandler {
    public static void createCreditNote(List<Invoice_Product_Line_Item__c> newRecords) {
		
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, Name FROM RecordType WHERE SObjectType = 'Invoice__c'
        ]) {
            recordTypeMap.put(rt.Name, rt.Id);
        }
        
        Set<Id> productIds = new Set<Id>();
        Set<Id> invoiceIds = new Set<Id>();
        
        for (Invoice_Product_Line_Item__c item : newRecords) {
            if (item.Zydus_Product__c != null) productIds.add(item.Zydus_Product__c);
            if (item.Invoice__c != null) invoiceIds.add(item.Invoice__c);
        }
        
        if (productIds.isEmpty() || invoiceIds.isEmpty()) return;
        
        Map<Id, Invoice__c> invoiceIdMap = new Map<Id, Invoice__c>(
            [SELECT Id, RecordTypeId, Consignor_Dealer__r.State__c,
             Consignee_Dealer__r.State__c, Consignee_Dealer__r.Zydus_Price_Book__c,
             Hospital__r.State__c, Hospital__r.Zydus_Price_Book__c
             FROM Invoice__c WHERE Id IN :invoiceIds]
        );
        
        Map<Id, Zydus_Product__c> zydusProductMap = new Map<Id, Zydus_Product__c>(
            [SELECT Id, HSN_Code__c FROM Zydus_Product__c WHERE Id IN :productIds]
        );
        
        Set<Id> hsnCodeIds = new Set<Id>();
        for (Zydus_Product__c zp : zydusProductMap.values()) {
            if (zp.HSN_Code__c != null) hsnCodeIds.add(zp.HSN_Code__c);
        }
        
        Set<Id> priceBookIds = new Set<Id>();
        Map<Id, Id> invoiceToPriceBook = new Map<Id, Id>();
        for (Invoice__c inv : invoiceIdMap.values()) {
            Id pbId;
            if (inv.RecordTypeId == recordTypeMap.get('Hospital Invoice')) {
                pbId = inv.Hospital__r.Zydus_Price_Book__c;
            } else {
                pbId = inv.Consignee_Dealer__r.Zydus_Price_Book__c;
            }
            if (pbId != null) {
                invoiceToPriceBook.put(inv.Id, pbId);
                priceBookIds.add(pbId);
            }
        }
        
        Map<String, Decimal> productPriceMap = new Map<String, Decimal>();
        for (Zydus_Price_Book_Entry__c pbe : [
            SELECT Zydus_Product__c, Zydus_Price_Book__c, Credit_Note_Amount__c
            FROM Zydus_Price_Book_Entry__c
            WHERE Zydus_Product__c IN :productIds AND Zydus_Price_Book__c IN :priceBookIds
        ]) {
            String key = pbe.Zydus_Product__c + '_' + pbe.Zydus_Price_Book__c;
            productPriceMap.put(key, pbe.Credit_Note_Amount__c);
        }
        
        Date today = Date.today();
        Map<String, HSN_Tax_Master_Link__c> taxRateMap = new Map<String, HSN_Tax_Master_Link__c>();
        for (HSN_Tax_Master_Link__c tax : [
            SELECT Id, HSN_Code__c, Supply_Type__c, CGST__c, SGST__c, IGST__c,
            Tax_Master__r.State__c
            FROM HSN_Tax_Master_Link__c
            WHERE HSN_Code__c IN :hsnCodeIds
            AND Is_Active__c = TRUE
            AND Tax_Master__r.Is_Active__c = TRUE
            AND Tax_Master__r.Effective_From__c <= :today
            AND (Tax_Master__r.Effective_To__c = NULL OR Tax_Master__r.Effective_To__c >= :today)
            AND HSN_Code__r.Is_Active__c = TRUE
        ]) {
            String key = tax.HSN_Code__c + '_' + tax.Tax_Master__r.State__c + '_' + tax.Supply_Type__c;
            taxRateMap.put(key, tax);
        }
        
        Map<Id, Decimal> baseAmountMap = new Map<Id, Decimal>();
        Map<Id, Decimal> cgstMap = new Map<Id, Decimal>();
        Map<Id, Decimal> sgstMap = new Map<Id, Decimal>();
        Map<Id, Decimal> igstMap = new Map<Id, Decimal>();
        
        for (Invoice_Product_Line_Item__c item : newRecords) {
            if (item.Zydus_Product__c == null || item.Invoice__c == null) continue;
            
            Id priceBookId = invoiceToPriceBook.get(item.Invoice__c);
            if (priceBookId == null) continue;
            
            String priceKey = item.Zydus_Product__c + '_' + priceBookId;
            Decimal baseCredit = productPriceMap.get(priceKey);
            if (baseCredit == null) continue;
            
            Zydus_Product__c zp = zydusProductMap.get(item.Zydus_Product__c);
            if (zp == null || zp.HSN_Code__c == null) continue;
            
            Invoice__c invoice = invoiceIdMap.get(item.Invoice__c);
            if (invoice == null) continue;
            
            String buyerState = (invoice.RecordTypeId == recordTypeMap.get('Hospital Invoice'))
                ? invoice.Hospital__r.State__c
                : invoice.Consignee_Dealer__r.State__c;
            
            String supplierState = invoice.Consignor_Dealer__r.State__c;
            String supplyType = (buyerState == supplierState) ? 'Intra-State' : 'Inter-State';
            
            String taxKey = zp.HSN_Code__c + '_' + supplierState + '_' + supplyType;
            HSN_Tax_Master_Link__c tax = taxRateMap.get(taxKey);
            
            Decimal cgst = 0, sgst = 0, igst = 0;
            if (tax != null) {
                if (supplyType == 'Intra-State') {
                    cgst = (baseCredit * tax.CGST__c) / 100;
                    sgst = (baseCredit * tax.SGST__c) / 100;
                } else {
                    igst = (baseCredit * tax.IGST__c) / 100;
                }
            }
            
            baseAmountMap.put(item.Invoice__c, baseAmountMap.get(item.Invoice__c) == null
                              ? baseCredit : baseAmountMap.get(item.Invoice__c) + baseCredit);
            
            cgstMap.put(item.Invoice__c, cgstMap.get(item.Invoice__c) == null
                        ? cgst : cgstMap.get(item.Invoice__c) + cgst);
            
            sgstMap.put(item.Invoice__c, sgstMap.get(item.Invoice__c) == null
                        ? sgst : sgstMap.get(item.Invoice__c) + sgst);
            
            igstMap.put(item.Invoice__c, igstMap.get(item.Invoice__c) == null
                        ? igst : igstMap.get(item.Invoice__c) + igst);
        }
        
        Id creditNoteRTId = [SELECT Id FROM RecordType
                             WHERE SObjectType = 'Credit_Note__c' AND DeveloperName = 'Invoice'
                             LIMIT 1].Id;
        
        Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>(
            [SELECT Id, Delivery_Challan__r.Supply_Order__c, Hospital__c
             FROM Invoice__c WHERE Id IN :baseAmountMap.keySet()]
        );
        
        List<Credit_Note__c> notesToInsert = new List<Credit_Note__c>();
        for (Id invoiceId : baseAmountMap.keySet()) {
            Invoice__c inv = invoiceMap.get(invoiceId);
            Invoice__c originalInvoice = invoiceIdMap.get(invoiceId);
            
            Credit_Note__c note = new Credit_Note__c();
            note.Account__c = originalInvoice.Consignor_Dealer__c;
            note.Date__c = Date.today();
            note.Amount__c = baseAmountMap.get(invoiceId);
            note.CGST__c = cgstMap.get(invoiceId);
            note.SGST__c = sgstMap.get(invoiceId);
            note.IGST__c = igstMap.get(invoiceId);
            note.Invoice__c = invoiceId;
            note.RecordTypeId = creditNoteRTId;
            
            if (originalInvoice.RecordTypeId == recordTypeMap.get('Hospital Invoice')) {
                note.Hospital__c = inv.Hospital__c;
            } else {
                note.Consignee_Dealer__c = originalInvoice.Consignee_Dealer__c;
            }
            
            if (inv.Delivery_Challan__r != null) {
                note.Supply_Order__c = inv.Delivery_Challan__r.Supply_Order__c;
            }
            
            notesToInsert.add(note);
        }
        
        if (!notesToInsert.isEmpty()) {
            insert notesToInsert;
        }
        Map<Id, Id> invoiceToCreditNote = new Map<Id, Id>();
        for (Credit_Note__c note : notesToInsert) {
            invoiceToCreditNote.put(note.Invoice__c, note.Id);
        }
        
        List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
        for (Id invoiceId : invoiceToCreditNote.keySet()) {
            Invoice__c updatedInvoice = new Invoice__c(
                Id = invoiceId,
                Credit_Note__c = invoiceToCreditNote.get(invoiceId)
            );
            invoicesToUpdate.add(updatedInvoice);
        }
        
        if (!invoicesToUpdate.isEmpty()) {
            update invoicesToUpdate;
        }

        System.enqueueJob(new enqueueSettleAutoCreditNote(notesToInsert,invoicesToUpdate));
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
                   ipli.addError('Cannot create invoice: Product is expired in the selected warehouse.');
               }
        }
    }
    
}