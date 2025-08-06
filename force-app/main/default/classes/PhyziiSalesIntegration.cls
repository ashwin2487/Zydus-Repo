@RestResource(urlMapping='/zydusDMS/v2/phyziiSales/*')
global with sharing class PhyziiSalesIntegration {
  global class APIResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Object data;
        public List<ErrorDetail> errors;
        @AuraEnabled public String apiVersion = '64.0';
        @AuraEnabled public DateTime responseTime;
        @AuraEnabled public Map<String, Object> metadata;
        
        public APIResponse() {
            this.success = true;
            this.errors = new List<ErrorDetail>();
            this.responseTime = DateTime.now();
            this.metadata = new Map<String, Object>();
        }
    }
    
    global class ErrorDetail {
        @AuraEnabled public String errorCode;    
        @AuraEnabled public String message;      
        @AuraEnabled public String field;        
        @AuraEnabled public String severity;     
        
        public ErrorDetail(String code, String msg, String fld, String sev) {
            this.errorCode = code;
            this.message = msg;
            this.field = fld;
            this.severity = sev;
        }
    }
    
    global class InvalidParameterException extends Exception {}
    
    global class ValidationResult {
        public Boolean isValid = true;
        public List<String> errors = new List<String>();
    }
    
    global class InvoiceSaleData {
        @AuraEnabled public String hospitalId;
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Decimal totalSalesQty;
        @AuraEnabled public Decimal totalSalesValue;
        @AuraEnabled public Date invoiceDueDate;
        @AuraEnabled public Decimal totalFocQty;
        @AuraEnabled public Decimal totalFocValue;
        @AuraEnabled public String productLineId;
        @AuraEnabled public String brandId;
        @AuraEnabled public List<InvoiceLineItemsData> invoiceLineItems;
        
        public InvoiceSaleData(String hospId, Date invDate, String invNum,Decimal totalSalesQty,Decimal totalSalesValue, Date invDueDate,
                               Decimal totalFocQty,Decimal totalFocValue,List<InvoiceLineItemsData> invoiceLineItems,String productLineId, String brandId) {
                                   this.hospitalId = hospId;
                                   this.invoiceDate = invDate;
                                   this.invoiceNumber = invNum;
                                   this.totalSalesQty = totalSalesQty;
                                   this.totalSalesValue = totalSalesValue;
                                   this.invoiceDueDate = invDueDate;
                                   this.totalFocQty = totalFocQty;
                                   this.totalFocValue = totalFocValue;
                                   this.invoiceLineItems= invoiceLineItems;
                                   this.productLineId = productLineId;
                                   this.brandId = brandId;
                               }
    }
    
      global class InvoiceLineItemsData {
        @AuraEnabled public String productLineId;
        @AuraEnabled public String brandId;
        @AuraEnabled public Decimal invoiceSalesQty;
        @AuraEnabled public Decimal invoiceSalesValue;
        @AuraEnabled public Decimal invoiceFocQty;
        @AuraEnabled public Decimal invoiceFocValue;
          public InvoiceLineItemsData(String productLineId, String brandId, Decimal invoiceSalesQty,Decimal invoiceSalesValue, Decimal invoiceFocQty,Decimal invoiceFocValue) {
            this.productLineId = productLineId;
            this.brandId = brandId;
            this.invoiceSalesQty = invoiceSalesQty;
            this.invoiceSalesValue = invoiceSalesValue;
            this.invoiceFocQty = invoiceFocQty;
            this.invoiceFocValue = invoiceFocValue;
        }
      }
    
    @HttpGet
    global static void getPaymentData() {
        APIResponse response = new APIResponse();
        
        Long startMillis = System.currentTimeMillis();
        DateTime startDT = DateTime.newInstance(startMillis);
        String formattedStart = startDT.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        response.metadata.put('requestId', generateRequestId());
        response.metadata.put('processingStartTime', formattedStart);
        
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            
            String startDateStr = req.params.get('startDate');
            String endDateStr = req.params.get('endDate');
            String hospitalID = req.params.get('hospitalID');
             String invoiceType = req.params.get('invoiceType');
            
            if (String.isBlank(startDateStr) || String.isBlank(endDateStr) || String.isBlank(hospitalID)) {
                response.success = false;
                response.errors.add(new ErrorDetail('MISSING_REQUIRED_PARAMS', 'startDate, endDate, and hospitalID are required query parameters.', 'parameters', 'ERROR'));
                res.statusCode = 400; 
                return;
            }
            
            Date startDate;
            Date endDate;
            try {
                startDate = Date.valueOf(startDateStr);
            } catch (Exception e) {
                response.success = false;
                response.errors.add(new ErrorDetail('INVALID_DATE_FORMAT', 'Invalid startDate format. Use YYYY-MM-DD.', 'startDate', 'ERROR'));
                res.statusCode = 400;
                return;
            }
            try {
                endDate = Date.valueOf(endDateStr);
            } catch (Exception e) {
                response.success = false;
                response.errors.add(new ErrorDetail('INVALID_DATE_FORMAT', 'Invalid endDate format. Use YYYY-MM-DD.', 'endDate', 'ERROR'));
                res.statusCode = 400;
                return;
            }
            
            if (startDate > endDate) {
                response.success = false;
                response.errors.add(new ErrorDetail('INVALID_DATE_RANGE', 'Start date cannot be after end date.', 'startDate/endDate', 'ERROR'));
                res.statusCode = 400;
                return;
            }
            
            if (endDate > Date.today()) {
                response.success = false;
                response.errors.add(new ErrorDetail('END_DATE_IN_FUTURE', 'End date cannot be in the future.', 'endDate', 'ERROR'));
                res.statusCode = 400;
                return;
            }
            
            try {
                String queryMain ='SELECT Id, Name, Hospital__c, Hospital__r.Phyzii_Hospital_ID__c, InvoiceDate__c, InvoiceNumber__c, ' +
                    'Comment__c, Comment_Remark__c, Consignee_Dealer__c, Consignor_Dealer__c, CreatedDate, Date_of_Implant__c, ' +
                    'Delivery_Challan__c, Description__c, Doctor_Name__c, Invoice_Closed__c, Invoice_Due_Date__c, Invoice_Type__c, ' +
                    'IP_Number__c, is_Invoiced_By_Parent__c, IsInvoiceLocked__c, Payment_Status__c, Record_Type_Name__c, ' +
                    'Status__c, Total_Amount__c, Total_Bill_Discount_Amount__c, Total_CGST__c, Total_Collected_Amount__c, ' +
                    'Total_IGST__c, Total_Pending_Amount__c, Total_SGST__c,Total_Quantity__c, ';
                String querySub ='(SELECT Id, Name, Before_Tax_Amount__c, Bill_Discount_Amount__c, CGST__c, Expiry_Date__c, HSN__c, IGST__c, Invoice__c,  Manufacture_Date__c, Net_Amount__c,'+
                    ' Scheme__c, Serial_Number__c, SGST__c, Unit_Price__c, Warehouse_Product_Line_Item__c, Zydus_Product__c, Zydus_Product__r.Material_Description__c,'+
                    'Zydus_Product__r.Brand__r.Name FROM Invoice_Product_Line_Items__r )';
                String queryFrom =' FROM Invoice__c ';
                String queryWhere ='WHERE RecordType.Name = \'Hospital Invoice\' ' +
                    'AND Hospital__r.Phyzii_Hospital_ID__c = :hospitalID ' +
                    'AND InvoiceDate__c >= :startDate ' +
                    'AND InvoiceDate__c <= :endDate ';
                if(!String.isEmpty(invoiceType)){
                    queryWhere +='AND Invoice_Type__c =:invoiceType';
                }
                String queryOrder ='ORDER BY InvoiceDate__c ASC, CreatedDate ASC';
                
                String query = queryMain+querySub+queryFrom+queryWhere+queryOrder;
                
                List<Invoice__c> invoiceRecords = Database.query(query);
                List<InvoiceSaleData> transformedData = new List<InvoiceSaleData>();
                for (Invoice__c inv : invoiceRecords) {
                    List<InvoiceLineItemsData> invoiceLineItems= New List<InvoiceLineItemsData>();
                   if(inv.Invoice_Product_Line_Items__r.size()>0){
                        //  String productLineId, String brandId, Decimal invoiceSalesQty,Decimal invoiceSalesValue, Decimal invoiceFocQty,Decimal invoiceFocValue)
                        for (Invoice_Product_Line_Item__c invLine : inv.Invoice_Product_Line_Items__r) {
                            invoiceLineItems.add(
                                New InvoiceLineItemsData (invLine.Zydus_Product__r.Material_Description__c,
                                                 invLine.Zydus_Product__r.Brand__r.Name,
                                                 1,
                                                 invLine.Unit_Price__c,
                                                 1,
                                                 invLine.Unit_Price__c
                                                )
                            );
                        }
                    }
                    transformedData.add(
                        new InvoiceSaleData(
                            inv.Hospital__r.Phyzii_Hospital_ID__c,
                            inv.InvoiceDate__c,
                            inv.InvoiceNumber__c,
                            inv.Total_Quantity__c,
                            inv.Total_Amount__c,
                            inv.InvoiceDate__c,
                            inv.Total_Quantity__c,
                            inv.Total_Amount__c,
                            invoiceLineItems,
                            inv.Invoice_Product_Line_Items__r[0].Zydus_Product__r.Material_Description__c,
                            inv.Invoice_Product_Line_Items__r[0].Zydus_Product__r.Brand__r.Name)
                    );
                }
                
                response.data = transformedData;
                response.message = 'Successfully retrieved ' + transformedData.size() + ' invoice payment data records.';
                res.statusCode = 200;
            } catch (QueryException qe) {
                response.success = false;
                response.errors.add(new ErrorDetail('QUERY_ERROR', 'SOQL query failed: ' + qe.getMessage(), 'soql', 'ERROR'));
                res.statusCode = 400;
            } catch (Exception e) {
                response.success = false;
                response.errors.add(new ErrorDetail('INTERNAL_SERVER_ERROR', 'An unexpected error occurred: ' + e.getMessage(), 'system', 'FATAL'));
                res.statusCode = 500;
            }
            
        } catch (Exception e) {
            response.success = false;
            response.errors.add(new ErrorDetail('API_EXCEPTION', 'An error occurred during API processing: ' + e.getMessage(), 'system', 'FATAL'));
            RestContext.response.statusCode = 500;
        } finally {
            Long endMillis = System.currentTimeMillis();
            DateTime endDT = DateTime.newInstance(endMillis);
            String formattedEnd = endDT.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            
            response.metadata.put('processingEndTime', formattedEnd);
            
            Long durationMs = endMillis - startMillis;
            
            Long hours = durationMs / (1000 * 60 * 60);
            Long minutes = (durationMs - (hours * 3600000)) / (1000 * 60);
            Long seconds = (durationMs - (hours * 3600000) - (minutes * 60000)) / 1000;
            Long milliseconds = durationMs - (hours * 3600000) - (minutes * 60000) - (seconds * 1000);
            
            String formattedDuration =
                padLeft(String.valueOf(hours), 2) + ':' +
                padLeft(String.valueOf(minutes), 2) + ':' +
                padLeft(String.valueOf(seconds), 2) + '.' +
                padLeft(String.valueOf(milliseconds), 3);
            
            
            
            response.metadata.put('processingDuration', formattedDuration);
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
            RestContext.response.headers.put('Content-Type', 'application/json');
        }
    }
    private static String padLeft(String value, Integer length) {
        while (value.length() < length) {
            value = '0' + value;
        }
        return value;
    }
    
    private static String generateRequestId() {
        return String.valueOf(System.currentTimeMillis()) + '_' + Math.round(Math.random() * 1000);
    }
}