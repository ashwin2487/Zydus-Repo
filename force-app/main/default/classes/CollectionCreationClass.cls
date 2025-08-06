public class CollectionCreationClass {
	
    public class RecordTypeWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;

        public RecordTypeWrapper(String id, String name) {
            this.id = id;
            this.name = name;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordTypeWrapper> getCollectionRecordTypes() {
        List<RecordTypeWrapper> recordTypes = new List<RecordTypeWrapper>();

        // Get the DescribeSObjectResult for Collection__c
        Schema.DescribeSObjectResult describeResult = Collection__c.sObjectType.getDescribe();

        // Get the RecordTypeInfo map
        for (Schema.RecordTypeInfo rtInfo : describeResult.getRecordTypeInfos()) {
            if (rtInfo.isAvailable()) {
                recordTypes.add(new RecordTypeWrapper(rtInfo.getRecordTypeId(), rtInfo.getName()));
            }
        }
        return recordTypes;
    }

	@AuraEnabled
public static InvoiceWrapper getInvoices(String objectApiName, String recordId) {
	InvoiceWrapper iw = new InvoiceWrapper();
    // Get current user ID (not used here but included from original)
    Id userId = UserInfo.getUserId();

    // Query the related Collection__c record
    Collection__c collection = [ SELECT Id, Name, Account__c,Collected_Amount__c,Consumed_Amount__c,Remaining_Amount__c,Collected_Mode__c, Hospital__c,Remarks__c,Available_Status__c  FROM Collection__c  WHERE Id = :recordId  LIMIT 1 ];

    // Initialize list to return
    List<Invoice__c> invoiceList = new List<Invoice__c>();

    // If collection is null, return empty
    if (collection == null) {
		
		iw.collection=null;
		iw.invoiceList=invoiceList;
        return iw;
    }

    // Build the query using inline binding
    if (collection.Hospital__c != null) {
        invoiceList = [
            SELECT Id, Consignee_Dealer__c, Consignor_Dealer__c, Delivery_Challan__c,
                   Description__c, Hospital__c, Invoice_Closed__c, Invoice_Due_Date__c, Invoice_Type__c,
                   InvoiceDate__c, InvoiceNumber__c, is_Invoiced_By_Parent__c, IsDeleted,
                	LastViewedDate, Name, OwnerId, Payment_Mode__c,
                   Payment_Status__c, Record_Type_Name__c, RecordTypeId, Status__c,
                   Total_Amount__c, Total_Bill_Discount_Amount__c, Total_CGST__c, Total_Collected_Amount__c,
                   Total_IGST__c, Total_Pending_Amount__c, Total_Quantity__c, Total_SGST__c
            FROM Invoice__c
            WHERE Hospital__c = :collection.Hospital__c
              AND Payment_Status__c != 'Fully Paid'
        ];
    } else if (collection.Account__c != null) {
        invoiceList = [
            SELECT Id, Consignee_Dealer__c, Consignor_Dealer__c, Delivery_Challan__c,
                   Description__c, Hospital__c, Invoice_Closed__c, Invoice_Due_Date__c, Invoice_Type__c,
                   InvoiceDate__c, InvoiceNumber__c, is_Invoiced_By_Parent__c, IsDeleted,
                	LastViewedDate, Name, OwnerId, Payment_Mode__c,
                   Payment_Status__c, Record_Type_Name__c, RecordTypeId, Status__c,
                   Total_Amount__c, Total_Bill_Discount_Amount__c, Total_CGST__c, Total_Collected_Amount__c,
                   Total_IGST__c, Total_Pending_Amount__c, Total_Quantity__c, Total_SGST__c
            FROM Invoice__c
            WHERE Consignor_Dealer__c = :collection.Account__c
              AND Payment_Status__c != 'Fully Paid'
        ];
    }
		iw.collection=collection;
		iw.invoiceList=invoiceList;
        return iw;
}

public class InvoiceWrapper {
		@AuraEnabled public Collection__c collection {get;set;}

		@AuraEnabled public   List<Invoice__c> invoiceList {get;set;}
	} 


	@AuraEnabled
	public static List<Collection__c> fetchCollections(String selectedRecordId){
return [SELECT Id,  Name,Account__c, Account_Name__c, AccountUrl__c, Collected_Amount__c, Collected_Mode__c, CollectionRecordUrl__c, Consumed_Amount__c,  Hospital__c, Hospital_Name__c, 
HospitalRecordUrl__c,   RecordTypeId, Remaining_Amount__c, Status__c,Remarks__c,Available_Status__c 
FROM Collection__c   WHERE Available_Status__c='Available' AND Hospital__c=:selectedRecordId];
	}

	

	public class ResponseWrapper {
		@AuraEnabled public String message {get;set;}
		@AuraEnabled public Boolean code {get;set;}
	} 

@AuraEnabled
public static ResponseWrapper saveCollectionLineItems(List<Collection_Line_Item__c> lineItems ,List<Invoice__c> invoiceUpdateList,List<Payment__C> paymentInsertList) {
    ResponseWrapper rw = new ResponseWrapper();
    List<String> messageList = new List<String>();

    try {
        // Perform partial insert (allowing individual failures)
        Database.SaveResult[] results = Database.insert(lineItems, false);
		Database.SaveResult[] resultsPaymentInsert = Database.insert(paymentInsertList, false);
		Database.SaveResult[] resultsInvoiceUpdate = Database.update(invoiceUpdateList, false);

        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    messageList.add('LineItem ' + i + ': ' + err.getMessage());
                }
            }
        }

        if (messageList.isEmpty()) {
            rw.code = true;
            rw.message = 'All Collection Line Items saved successfully.';
        } else {
            rw.code = false;
            rw.message = 'Some errors occurred: ' + String.join(messageList, '; ');
        }

    } catch (Exception e) {
        rw.code = false;
        rw.message = 'Unexpected error: ' + e.getMessage();
    }
    return rw;
}

	@AuraEnabled 
    public static List<Credit_Note__c> getCreditNoteList(String consigneeHospitalId,String consigneeDealerId, Boolean isHospital ) {
         Id userId = UserInfo.getUserId();
        List<Credit_Note__c> creditNotes = New List<Credit_Note__c> ();
        if(isHospital){
                creditNotes = [
                        SELECT Id, Amount__c,Available_Amount__c, Consumed_Amount__c,Name,CGST__c,IGST__c,SGST__c
                        FROM Credit_Note__c 
                        WHERE Is_used__c = false  AND CreatedById=:userId AND Hospital__c = :consigneeHospitalId 
                    ];//AND Account__c =:userId
            
        }else{
                creditNotes = [
                            SELECT Id, Amount__c,Available_Amount__c, Consumed_Amount__c,Name,CGST__c,IGST__c,SGST__c
                            FROM Credit_Note__c 
                            WHERE Is_used__c = false AND CreatedById=:userId AND Consignee_Dealer__c=:consigneeDealerId
                        ];//AND Account__c = :userId
        }
        return creditNotes;
    }

 @AuraEnabled
public static ResponseWrapper saveInvoicePaymentWithCreditNote(Invoice__c invoiceInput, Payment__c paymentInput, List<Credit_Note__c> updatedCreditNotesList) {
    ResponseWrapper rw = new ResponseWrapper();
    List<String> messageList = new List<String>();

    try {
        // Save Invoice (update)
        Database.SaveResult invoiceResult = Database.update(invoiceInput, false);

        // Save Payment (insert)
        Database.SaveResult paymentResult = Database.insert(paymentInput, false);

        // Save Credit Notes (update list)
        Database.SaveResult[] creditNoteResults = Database.update(updatedCreditNotesList, false);

        // Check for invoice save errors
        if (!invoiceResult.isSuccess()) {
            for (Database.Error err : invoiceResult.getErrors()) {
                messageList.add('Invoice Error: ' + err.getMessage());
            }
        }

        // Check for payment save errors
        if (!paymentResult.isSuccess()) {
            for (Database.Error err : paymentResult.getErrors()) {
                messageList.add('Payment Error: ' + err.getMessage());
            }
        }

        // Check for credit note update errors
        for (Integer i = 0; i < creditNoteResults.size(); i++) {
            if (!creditNoteResults[i].isSuccess()) {
                for (Database.Error err : creditNoteResults[i].getErrors()) {
                    messageList.add('Credit Note ' + i + ': ' + err.getMessage());
                }
            }
        }

        if (messageList.isEmpty()) {
            rw.code = true;
            rw.message = 'Invoice, payment, and credit notes saved successfully.';
        } else {
            rw.code = false;
            rw.message = 'Some errors occurred: ' + String.join(messageList, '; ');
        }

    } catch (Exception e) {
        rw.code = false;
        rw.message = 'Unexpected error: ' + e.getMessage();
    }

    return rw;
}


   
}