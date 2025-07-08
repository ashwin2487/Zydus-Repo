@RestResource(urlMapping='/zydusDMS/v2/hospitalStock/*')
global with sharing class SAPHospitalStockAPI {
    
    global class APIResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Object data;
        @AuraEnabled public List<ErrorDetail> errors = new List<ErrorDetail>();
        @AuraEnabled public String apiVersion = '64.0';
        @AuraEnabled public DateTime responseTime = DateTime.now();
        @AuraEnabled public Map<String, Object> metadata = new Map<String, Object>();
        
        public APIResponse() {
            this.success = true;
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
    
    @HttpGet
    global static void getHospitalStock() {
        APIResponse response = new APIResponse();
        Long processingStart = System.currentTimeMillis();
        response.metadata.put('requestId', generateRequestId());
        
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            
            String hospitalIdParam = req.params.get('hospitalID');
            String statusFilter = req.params.get('status'); // Optional
            
            if (String.isBlank(hospitalIdParam)) {
                response.success = false;
                response.errors.add(new ErrorDetail('MISSING_PARAM', 'hospitalID is required (comma-separated for multiple).', 'hospitalID', 'ERROR'));
                res.statusCode = 400;
                finalizeResponse(response, processingStart);
                return;
            }

            List<String> hospitalIds = new List<String>();
            for (String idVal : hospitalIdParam.split(',')) {
                if (!String.isBlank(idVal)) {
                    hospitalIds.add(idVal.trim());
                }
            }

            if (hospitalIds.isEmpty()) {
                response.success = false;
                response.errors.add(new ErrorDetail('INVALID_PARAM', 'No valid hospitalIDs were provided.', 'hospitalID', 'ERROR'));
                res.statusCode = 400;
                finalizeResponse(response, processingStart);
                return;
            }

            Map<String, Id> phyziiIdToHospitalId = new Map<String, Id>();
            for (Hospital__c hosp : [
                SELECT Id, Phyzii_Hospital_ID__c 
                FROM Hospital__c 
                WHERE Phyzii_Hospital_ID__c IN :hospitalIds
            ]) {
                phyziiIdToHospitalId.put(hosp.Phyzii_Hospital_ID__c, hosp.Id);
            }

            if (phyziiIdToHospitalId.isEmpty()) {
                response.success = false;
                response.errors.add(new ErrorDetail('NOT_FOUND', 'No hospitals matched the provided hospitalIDs.', 'hospitalID', 'ERROR'));
                res.statusCode = 404;
                finalizeResponse(response, processingStart);
                return;
            }

            Set<Id> hospitalIdSet = new Set<Id>(phyziiIdToHospitalId.values());
            List<Warehouse__c> warehouses = [
                SELECT Id, Hospital__c 
                FROM Warehouse__c 
                WHERE Hospital__c IN :hospitalIdSet
            ];

            List<Id> warehouseIds = new List<Id>();
            for (Warehouse__c wh : warehouses) {
                warehouseIds.add(wh.Id);
            }

            if (warehouseIds.isEmpty()) {
                response.success = false;
                response.errors.add(new ErrorDetail('NO_WAREHOUSES', 'No warehouses found for the provided hospitalIDs.', 'warehouse', 'ERROR'));
                res.statusCode = 404;
                finalizeResponse(response, processingStart);
                return;
            }

            List<Map<String, Object>> inventory = WarehouseInventoryController.getInventoryData(warehouseIds, statusFilter);

            response.data = inventory;
            response.message = 'Retrieved ' + inventory.size() + ' stock record(s).';
            res.statusCode = 200;

        } catch (Exception e) {
            response.success = false;
            response.errors.add(new ErrorDetail('UNEXPECTED_ERROR', e.getMessage(), 'system', 'FATAL'));
            RestContext.response.statusCode = 500;
        } finally {
            finalizeResponse(response, processingStart);
        }
    }

    private static void finalizeResponse(APIResponse response, Long startTime) {
        Long endTime = System.currentTimeMillis();
        Long duration = endTime - startTime;
        
        response.metadata.put('processingStartTime', formatTimestamp(startTime));
        response.metadata.put('processingEndTime', formatTimestamp(endTime));
        response.metadata.put('processingDuration', formatDuration(duration));
        
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
        RestContext.response.headers.put('Content-Type', 'application/json');
    }

    private static String generateRequestId() {
        return String.valueOf(Crypto.getRandomInteger()) + '_' + String.valueOf(DateTime.now().getTime());
    }

    private static String formatTimestamp(Long ms) {
        return DateTime.newInstance(ms).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    }

    private static String formatDuration(Long millis) {
        Long hours = millis / (1000 * 60 * 60);
        Long minutes = (millis - (hours * 1000 * 60 * 60)) / (1000 * 60);
        Long seconds = (millis - (hours * 3600000) - (minutes * 60000)) / 1000;
        Long ms = millis - (hours * 3600000) - (minutes * 60000) - (seconds * 1000);
        
        return padLeft(String.valueOf(hours), 2) + ':' +
               padLeft(String.valueOf(minutes), 2) + ':' +
               padLeft(String.valueOf(seconds), 2) + '.' +
               padLeft(String.valueOf(ms), 3);
    }

    private static String padLeft(String input, Integer totalLength) {
        while (input.length() < totalLength) {
            input = '0' + input;
        }
        return input;
    }
}