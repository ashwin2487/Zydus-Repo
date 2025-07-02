/**
 * @name SAPIntegrationAPIv2
 * @description A RESTful API for integrating with SAP systems, providing V2 endpoints
 * for retrieving data from Salesforce objects with enhanced features
 * like dynamic field selection, robust pagination (offset and cursor-based),
 * and comprehensive error handling with detailed logging.
 * @urlMapping /sap/v2/data/*
 * @methods GET
 */
@RestResource(urlMapping='/sap/v2/data/*')
global with sharing class SAPIntegrationAPIv2 {

    /**
     * @description Represents the standard response structure for all API calls,
     * providing consistent feedback including success status, messages,
     * data, pagination information, and detailed errors.
     */
    global class APIResponse {
        public Boolean success;
        public String message;
        public Object data;
        public Integer totalRecords;
        public String nextRecordsUrl;
        public List<ErrorDetail> errors;
        public String apiVersion = '64.0';
        public DateTime responseTime;
        public Map<String, Object> metadata;

        /**
         * @description Constructor for APIResponse. Initializes success to true,
         * creates empty error list, sets response time, and initializes metadata map.
         */
        public APIResponse() {
            this.success = true;
            this.errors = new List<ErrorDetail>();
            this.responseTime = DateTime.now();
            this.metadata = new Map<String, Object>();
        }
    }

    /**
     * @description Provides detailed information about an error that occurred during an API call,
     * including an error code, message, field, severity, and a help URL.
     */
    global class ErrorDetail {
        public String errorCode;
        public String message;
        public String field;
        public String severity;
        public String helpUrl;

        /**
         * @description Constructor for ErrorDetail.
         * @param code The specific error code (e.g., 'VALIDATION_ERROR', 'QUERY_ERROR').
         * @param msg A human-readable message describing the error.
         * @param fld The field or parameter related to the error, if applicable.
         * @param sev The severity of the error (e.g., 'ERROR', 'WARNING', 'FATAL').
         */
        public ErrorDetail(String code, String msg, String fld, String sev) {
            this.errorCode = code;
            this.message = msg;
            this.field = fld;
            this.severity = sev;
            this.helpUrl = 'https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/';
        }
    }

    /**
     * @description Encapsulates pagination parameters for API requests, supporting
     * both offset-based and cursor-based (using SystemModstamp) pagination.
     */
    global class PaginationParams {
        public Integer pageSize = 100; // Default page size
        public Integer offset = 0;     // Default offset
        public String cursor;          // Cursor for next set of records (e.g., SystemModstamp value)
        public Boolean useCursor = false; // Flag to indicate if cursor-based pagination is used
    }

    /**
     * @description Captures contextual information about an incoming API request,
     * useful for logging and debugging purposes.
     */
    global class RequestContext {
        public String userAgent;    // User-Agent header from the request
        public String clientIP;     // Client IP address (from X-Forwarded-For header)
        public String sessionId;    // Salesforce session ID, if available (not explicitly populated here)
        public DateTime requestTime; // Timestamp when the request was received
        public Map<String, String> headers; // All request headers

        /**
         * @description Constructor for RequestContext. Initializes request time and headers map.
         */
        public RequestContext() {
            this.requestTime = DateTime.now();
            this.headers = new Map<String, String>();
        }
    }

    /**
     * @description Custom exception class for invalid parameter errors.
     */
    global class InvalidParameterException extends Exception {}

    /**
     * @description Holds the result of parameter validation, indicating if validation passed
     * and a list of errors if it failed.
     */
    global class ValidationResult {
        public Boolean isValid = true;
        public List<String> errors = new List<String>();
    }

    /**
     * @description Handles GET requests to retrieve data for specified Salesforce objects.
     * Supports filtering by ID, date ranges, dynamic fields, and pagination.
     * The response is serialized to JSON and set as the response body.
     */
    @HttpGet
    global static void getData() {
        APIResponse response = new APIResponse();
        RequestContext context = new RequestContext();

        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;

            // Populate request context details
            context.userAgent = req.headers.get('User-Agent');
            context.clientIP = req.headers.get('X-Forwarded-For');
            // context.sessionId = UserInfo.getSessionId(); // Uncomment if session ID is needed and accessible
            context.headers = req.headers; // Store all headers

            // Extract query parameters
            String objectType = req.params.get('object');
            String recordId = req.params.get('id');
            String startDate = req.params.get('startDate');
            String endDate = req.params.get('endDate');
            String pageSize = req.params.get('pageSize');
            String offset = req.params.get('offset');
            String cursor = req.params.get('cursor');
            String includeDeleted = req.params.get('includeDeleted'); // Not fully implemented due to ALL ROWS limitations
            String fields = req.params.get('fields');

            // Validate essential parameters
            ValidationResult validation = validateParameters(objectType, recordId, startDate, endDate, pageSize, offset);
            if (!validation.isValid) {
                response.success = false;
                for (String error : validation.errors) {
                    response.errors.add(new ErrorDetail('VALIDATION_ERROR', error, 'parameters', 'ERROR'));
                }
                res.statusCode = 400; // Bad Request
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                res.headers.put('Content-Type', 'application/json');
                return;
            }

            // Setup pagination parameters based on request
            PaginationParams pagination = setupPagination(pageSize, offset, cursor);

            // Add initial metadata for tracing and timing
            response.metadata.put('requestId', generateRequestId());
            Long processingStartTime = System.currentTimeMillis();
            response.metadata.put('processingTimeStart', processingStartTime);

            // Route to specific data retrieval methods based on object type
            switch on objectType.toLowerCase() {
                when 'account' {
                    getAccountDataV2(response, recordId, startDate, endDate, pagination, includeDeleted, fields, context);
                }
                when 'opportunity' {
                    getOpportunityDataV2(response, recordId, startDate, endDate, pagination, includeDeleted, fields, context);
                }
                when 'contact' {
                    getContactDataV2(response, recordId, startDate, endDate, pagination, includeDeleted, fields, context);
                }
                when 'case' {
                    getCaseDataV2(response, recordId, startDate, endDate, pagination, includeDeleted, fields, context);
                }
                when else {
                    response.success = false;
                    response.errors.add(new ErrorDetail('INVALID_OBJECT', 'Unsupported object type: ' + objectType, 'object', 'ERROR'));
                    res.statusCode = 400; // Bad Request
                }
            }

        } catch (Exception e) {
            // Catch any unexpected exceptions and handle them gracefully
            handleExceptionV2(response, e, context);
        }

        // Final step: Serialize the response and set it as the response body
        // This is done once at the end of the method, regardless of the path taken
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
        RestContext.response.headers.put('Content-Type', 'application/json');
    }

    /**
     * @description Retrieves Account records based on provided filters and pagination.
     * Populates the provided APIResponse object with data or errors.
     * @param response The APIResponse object to populate.
     * @param recordId Optional. The ID of a specific Account to retrieve.
     * @param startDate Optional. Filters records created on or after this date.
     * @param endDate Optional. Filters records created on or before this date.
     * @param pagination PaginationParams object containing page size, offset, or cursor.
     * @param includeDeleted Optional. Flag to include deleted records (not fully supported with date filters).
     * @param fields Optional. Comma-separated list of fields to retrieve. Defaults if empty.
     * @param context The RequestContext containing details of the original request.
     */
    private static void getAccountDataV2(APIResponse response, String recordId, String startDate, String endDate,
                                         PaginationParams pagination, String includeDeleted, String fields, RequestContext context) {
        try {
            // Determine the fields to query. Default to essential fields if not specified.
            String fieldList = String.isNotBlank(fields) ?
                               fields :
                               'Id, Name, BillingAddress, Industry, CreatedDate, LastModifiedDate, SystemModstamp';

            String query = 'SELECT ' + fieldList + ' FROM Account';

            // Build the WHERE clause based on record ID, date range, and other filters
            String whereClause = buildEnhancedWhereClause(recordId, startDate, endDate, 'CreatedDate');

            // Append WHERE clause if conditions exist
            if (String.isNotBlank(whereClause)) {
                query += ' WHERE ' + whereClause;
            }

            // Apply pagination logic (cursor-based or offset-based)
            if (pagination.useCursor && String.isNotBlank(pagination.cursor)) {
                // For cursor-based pagination, add an AND condition for SystemModstamp
                // This assumes SystemModstamp is indexed and monotonically increasing
                query += (String.isNotBlank(whereClause) ? ' AND' : ' WHERE') + ' SystemModstamp > ' + pagination.cursor;
                query += ' ORDER BY SystemModstamp ASC LIMIT ' + pagination.pageSize;
            } else {
                // Offset-based pagination with a default order
                query += ' ORDER BY CreatedDate DESC LIMIT ' + pagination.pageSize + ' OFFSET ' + pagination.offset;
            }

            // Execute the SOQL query
            List<Account> accounts;
            try {
                accounts = Database.query(query);
            } catch (QueryException qe) {
                // Handle SOQL query specific errors
                response.success = false;
                response.errors.add(new ErrorDetail('QUERY_ERROR', qe.getMessage(), 'soql', 'ERROR'));
                RestContext.response.statusCode = 400; // Bad Request
                return; // Exit method on error
            }

            // Get total count of records matching the WHERE clause (without pagination limits)
            String countQuery = 'SELECT COUNT() FROM Account';
            if (String.isNotBlank(whereClause)) {
                countQuery += ' WHERE ' + whereClause;
            }

            Integer totalCount;
            try {
                totalCount = Database.countQuery(countQuery);
            } catch (Exception e) {
                // Fallback for count query failure, use size of returned records
                System.debug('Error getting total count: ' + e.getMessage());
                totalCount = accounts.size();
                response.errors.add(new ErrorDetail('COUNT_ERROR', 'Could not retrieve full total count; providing count of returned records.', 'totalRecords', 'WARNING'));
            }

            response.data = accounts;
            response.totalRecords = totalCount;

            // Generate nextRecordsUrl for pagination
            if (pagination.useCursor && !accounts.isEmpty()) {
                // If using cursor, the next cursor is the SystemModstamp of the last record returned
                Account lastRecord = accounts[accounts.size() - 1];
                // Format SystemModstamp to ISO 8601 for consistent cursor value
                String nextCursorValue = lastRecord.SystemModstamp.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                response.nextRecordsUrl = '/services/apexrest/sap/v2/data/?object=account&cursor=' +
                                          EncodingUtil.urlEncode(nextCursorValue, 'UTF-8') +
                                          '&pageSize=' + pagination.pageSize +
                                          (String.isNotBlank(startDate) ? '&startDate=' + EncodingUtil.urlEncode(startDate, 'UTF-8') : '') +
                                          (String.isNotBlank(endDate) ? '&endDate=' + EncodingUtil.urlEncode(endDate, 'UTF-8') : '');
            } else if (pagination.offset + pagination.pageSize < totalCount) {
                // If using offset, calculate the next offset
                response.nextRecordsUrl = '/services/apexrest/sap/v2/data/?object=account&pageSize=' +
                                          pagination.pageSize + '&offset=' + (pagination.offset + pagination.pageSize) +
                                          (String.isNotBlank(startDate) ? '&startDate=' + EncodingUtil.urlEncode(startDate, 'UTF-8') : '') +
                                          (String.isNotBlank(endDate) ? '&endDate=' + EncodingUtil.urlEncode(endDate, 'UTF-8') : '');
            }

            // Finalize metadata including processing time
            response.metadata.put('processingTime', System.currentTimeMillis() - (Long)response.metadata.get('processingTimeStart'));
            response.metadata.put('queryStats', new Map<String, Object>{
                'recordsReturned' => accounts.size(),
                'soqlQuery' => query // For debugging, consider removing in production for security/governor limits
            });
            response.success = true; // Ensure success is set to true upon successful data retrieval

        } catch (Exception e) {
            // Catch any unexpected exceptions during data retrieval and add to response
            handleExceptionV2(response, e, context);
        }
    }

    /**
     * @description Placeholder method for retrieving Opportunity data.
     * Populates the provided APIResponse object with data or errors.
     * @param response The APIResponse object to populate.
     * @param recordId Optional. The ID of a specific Opportunity to retrieve.
     * @param startDate Optional. Filters records created on or after this date.
     * @param endDate Optional. Filters records created on or before this date.
     * @param pagination PaginationParams object containing page size, offset, or cursor.
     * @param includeDeleted Optional. Flag to include deleted records.
     * @param fields Optional. Comma-separated list of fields to retrieve. Defaults if empty.
     * @param context The RequestContext containing details of the original request.
     */
    private static void getOpportunityDataV2(APIResponse response, String recordId, String startDate, String endDate, PaginationParams pagination, String includeDeleted, String fields, RequestContext context) {
        response.success = false;
        response.message = 'Opportunity data retrieval not yet implemented.';
        response.errors.add(new ErrorDetail('NOT_IMPLEMENTED', 'This endpoint is under construction.', 'object', 'INFO'));
        RestContext.response.statusCode = 501; // Not Implemented
    }

    /**
     * @description Placeholder method for retrieving Contact data.
     * Populates the provided APIResponse object with data or errors.
     * @param response The APIResponse object to populate.
     * @param recordId Optional. The ID of a specific Contact to retrieve.
     * @param startDate Optional. Filters records created on or after this date.
     * @param endDate Optional. Filters records created on or before this date.
     * @param pagination PaginationParams object containing page size, offset, or cursor.
     * @param includeDeleted Optional. Flag to include deleted records.
     * @param fields Optional. Comma-separated list of fields to retrieve. Defaults if empty.
     * @param context The RequestContext containing details of the original request.
     */
    private static void getContactDataV2(APIResponse response, String recordId, String startDate, String endDate, PaginationParams pagination, String includeDeleted, String fields, RequestContext context) {
        response.success = false;
        response.message = 'Contact data retrieval not yet implemented.';
        response.errors.add(new ErrorDetail('NOT_IMPLEMENTED', 'This endpoint is under construction.', 'object', 'INFO'));
        RestContext.response.statusCode = 501; // Not Implemented
    }

    /**
     * @description Placeholder method for retrieving Case data.
     * Populates the provided APIResponse object with data or errors.
     * @param response The APIResponse object to populate.
     * @param recordId Optional. The ID of a specific Case to retrieve.
     * @param startDate Optional. Filters records created on or after this date.
     * @param endDate Optional. Filters records created on or before this date.
     * @param pagination PaginationParams object containing page size, offset, or cursor.
     * @param includeDeleted Optional. Flag to include deleted records.
     * @param fields Optional. Comma-separated list of fields to retrieve. Defaults if empty.
     * @param context The RequestContext containing details of the original request.
     */
    private static void getCaseDataV2(APIResponse response, String recordId, String startDate, String endDate, PaginationParams pagination, String includeDeleted, String fields, RequestContext context) {
        response.success = false;
        response.message = 'Case data retrieval not yet implemented.';
        response.errors.add(new ErrorDetail('NOT_IMPLEMENTED', 'This endpoint is under construction.', 'object', 'INFO'));
        RestContext.response.statusCode = 501; // Not Implemented
    }

    /**
     * @description Builds a SOQL WHERE clause based on record ID, date range, and an optional
     * flag to include deleted records.
     * @param recordId Optional. The ID to filter by.
     * @param startDate Optional. The start date for a date range filter.
     * @param endDate Optional. The end date for a date range filter.
     * @param dateField The API name of the date field to use for filtering (e.g., 'CreatedDate').
     * @return A string representing the SOQL WHERE clause, or an empty string if no conditions.
     * @throws InvalidParameterException if ID or date formats are incorrect.
     */
    private static String buildEnhancedWhereClause(String recordId, String startDate, String endDate,
                                                   String dateField) {
        List<String> conditions = new List<String>();

        // Filter by specific record ID
        if (String.isNotBlank(recordId)) {
            // Basic Salesforce ID format validation
            if (recordId.length() != 15 && recordId.length() != 18) {
                throw new InvalidParameterException('Invalid Salesforce ID format: ' + recordId);
            }
            conditions.add('Id = \'' + String.escapeSingleQuotes(recordId) + '\'');
        }

        // Filter by start date
        if (String.isNotBlank(startDate)) {
            try {
                // Assuming ISO 8601 format (e.g., '2023-01-15T10:30:00Z')
                DateTime parsedStartDate = DateTime.valueOfGmt(startDate);
                conditions.add(dateField + ' >= ' + parsedStartDate.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
            } catch (Exception e) {
                throw new InvalidParameterException('Invalid startDate format. Use ISO 8601 format (e.g., 2023-01-15T10:30:00Z).');
            }
        }

        // Filter by end date
        if (String.isNotBlank(endDate)) {
            try {
                // Assuming ISO 8601 format (e.g., '2023-01-15T10:30:00Z')
                DateTime parsedEndDate = DateTime.valueOfGmt(endDate);
                conditions.add(dateField + ' <= ' + parsedEndDate.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
            } catch (Exception e) {
                throw new InvalidParameterException('Invalid endDate format. Use ISO 8601 format (e.g., 2023-01-15T10:30:00Z).');
            }
        }

        // Note: 'includeDeleted' parameter is not directly used here with 'ALL ROWS'
        // because ALL ROWS cannot be used with date/time fields in the WHERE clause.
        // Implementing 'includeDeleted' would require a different approach, e.g., a separate endpoint
        // or a different SOQL pattern, which is beyond the scope of a single WHERE clause builder.

        return String.join(conditions, ' AND ');
    }

    /**
     * @description Handles exceptions gracefully, formats error responses, and sets appropriate HTTP status codes.
     * Populates the provided APIResponse object with error details and updates the HTTP status code.
     * @param response The APIResponse object to populate with error details.
     * @param e The exception that was caught.
     * @param context The RequestContext containing details of the original request.
     */
    private static void handleExceptionV2(APIResponse response, Exception e, RequestContext context) {
        response.success = false;
        RestResponse res = RestContext.response;

        // Classify common exception types for specific error codes and status codes
        if (e instanceof QueryException) {
            response.errors.add(new ErrorDetail('QUERY_ERROR', e.getMessage(), 'soql', 'ERROR'));
            res.statusCode = 400; // Bad Request (due to malformed query)
        } else if (e instanceof DmlException) {
            response.errors.add(new ErrorDetail('DML_ERROR', e.getMessage(), 'data', 'ERROR'));
            res.statusCode = 400; // Bad Request (due to data operation error)
        } else if (e instanceof System.LimitException) {
            response.errors.add(new ErrorDetail('LIMIT_EXCEEDED', 'Governor limit exceeded: ' + e.getMessage(), 'limits', 'ERROR'));
            res.statusCode = 429; // Too Many Requests
        } else if (e instanceof InvalidParameterException) {
            response.errors.add(new ErrorDetail('INVALID_PARAMETER', e.getMessage(), 'parameters', 'ERROR'));
            res.statusCode = 400; // Bad Request
        } else if (e instanceof System.SecurityException) {
            response.errors.add(new ErrorDetail('SECURITY_ERROR', 'Insufficient permissions: ' + e.getMessage(), 'security', 'ERROR'));
            res.statusCode = 403; // Forbidden
        } else {
            // Catch-all for any other unexpected exceptions
            response.errors.add(new ErrorDetail('INTERNAL_SERVER_ERROR', 'An unexpected error occurred: ' + e.getMessage(), 'system', 'FATAL'));
            res.statusCode = 500; // Internal Server Error
        }

        // Add detailed error context to metadata for debugging
        response.metadata.put('errorContext', new Map<String, Object>{
            'timestamp' => context.requestTime,
            'userAgent' => context.userAgent,
            'clientIP' => context.clientIP,
            'exceptionType' => e.getTypeName(),
            'exceptionMessage' => e.getMessage(),
            'stackTrace' => e.getStackTraceString()
        });
    }

    /**
     * @description Validates the incoming request parameters.
     * @param objectType The type of Salesforce object requested.
     * @param recordId The ID of a specific record.
     * @param startDate The start date for filtering.
     * @param endDate The end date for filtering.
     * @param pageSize The requested page size.
     * @param offset The requested offset.
     * @return A ValidationResult object indicating success or failure with a list of errors.
     */
    private static ValidationResult validateParameters(String objectType, String recordId,
                                                       String startDate, String endDate,
                                                       String pageSize, String offset) {
        ValidationResult result = new ValidationResult();

        // Object type is mandatory
        if (String.isBlank(objectType)) {
            result.isValid = false;
            result.errors.add('Object type is required.');
        }

        // Page size validation
        if (String.isNotBlank(pageSize)) {
            try {
                Integer size = Integer.valueOf(pageSize);
                if (size <= 0 || size > 2000) {
                    result.isValid = false;
                    result.errors.add('Page size must be between 1 and 2000.');
                }
            } catch (Exception e) {
                result.isValid = false;
                result.errors.add('Invalid page size format. Must be an integer.');
            }
        }

        // Offset validation
        if (String.isNotBlank(offset)) {
            try {
                Integer off = Integer.valueOf(offset);
                if (off < 0) {
                    result.isValid = false;
                    result.errors.add('Offset cannot be negative.');
                }
            } catch (Exception e) {
                result.isValid = false;
                result.errors.add('Invalid offset format. Must be an integer.');
            }
        }
        // Further date format validation is handled within buildEnhancedWhereClause via InvalidParameterException

        return result;
    }

    /**
     * @description Sets up pagination parameters from request strings.
     * @param pageSize The requested page size string.
     * @param offset The requested offset string.
     * @param cursor The requested cursor string.
     * @return A populated PaginationParams object.
     */
    private static PaginationParams setupPagination(String pageSize, String offset, String cursor) {
        PaginationParams pagination = new PaginationParams();

        if (String.isNotBlank(cursor)) {
            pagination.useCursor = true;
            pagination.cursor = cursor;
        }

        if (String.isNotBlank(pageSize)) {
            // Ensure pageSize does not exceed a reasonable max (e.g., 2000 for SOQL governor limit)
            pagination.pageSize = Math.min(Integer.valueOf(pageSize), 2000);
        }

        if (String.isNotBlank(offset) && !pagination.useCursor) {
            // Offset is only applicable if not using cursor-based pagination
            pagination.offset = Integer.valueOf(offset);
        }

        return pagination;
    }

    /**
     * @description Generates a unique request ID using current timestamp and a random number.
     * @return A string representing a unique request ID.
     */
    private static String generateRequestId() {
        return String.valueOf(System.currentTimeMillis()) + '_' + Math.round(Math.random() * 1000);
    }
}