@RestResource(urlMapping='/zydusDMS/v2/paymentData/*')
global with sharing class SAPPaymentDataAPI {
    
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
    
    global class InvoicePaymentData {
        @AuraEnabled public String hospitalId;
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Date paymentRecDate;
        @AuraEnabled public Decimal paymentRecAmt;
        
        public InvoicePaymentData(String hospId, Date invDate, String invNum, Date pRecDate, Decimal pRecAmt) {
            this.hospitalId = hospId;
            this.invoiceDate = invDate;
            this.invoiceNumber = invNum;
            this.paymentRecDate = pRecDate;
            this.paymentRecAmt = pRecAmt;
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
                String query = 'SELECT Id, CreatedDate, Amount__c, ' +
                    'Invoice__r.InvoiceDate__c, Invoice__r.InvoiceNumber__c, ' +
                    'Invoice__r.Hospital__r.Phyzii_Hospital_ID__c ' +
                    'FROM Payment__c ' +
                    'WHERE Invoice__r.RecordType.Name = \'Hospital Invoice\' ' +
                    'AND Invoice__r.Hospital__r.Phyzii_Hospital_ID__c = :hospitalID ' +
                    'AND Invoice__r.InvoiceDate__c >= :startDate ' +
                    'AND Invoice__r.InvoiceDate__c <= :endDate ' +
                    'ORDER BY Invoice__r.InvoiceDate__c ASC, CreatedDate ASC';
                
                List<Payment__c> paymentRecords = Database.query(query);
                List<InvoicePaymentData> transformedData = new List<InvoicePaymentData>();
                
                for (Payment__c pmt : paymentRecords) {
                    transformedData.add(new InvoicePaymentData(
                        pmt.Invoice__r.Hospital__r.Phyzii_Hospital_ID__c,
                        pmt.Invoice__r.InvoiceDate__c,
                        pmt.Invoice__r.InvoiceNumber__c,
                        pmt.CreatedDate.date(),
                        pmt.Amount__c
                    ));
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