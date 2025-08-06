public without sharing class ZydusReportsController {
    @AuraEnabled(cacheable=true)
    public static List<ApprovalStepWrapper> getAllApprovalHistory(String category) {
        List<SObject> records;
        Map<Id, SObject> recordMap = new Map<Id, SObject>();
        
        if (category == 'Hospital') {
            records = [SELECT Id, Name, L1_Approved__c, L2_Approved__c, Active__c FROM Hospital__c];
        } else {
            records = [SELECT Id, Name, L1_Approved__c, L2_Approved__c, Active__c FROM Account];
        }
        
        for (SObject rec : records) {
            recordMap.put(rec.Id, rec);
        }
        
        List<ProcessInstance> instances = [SELECT Id, Status, CreatedDate, TargetObjectId,
                                           (SELECT Actor.Name, StepStatus, Comments, CreatedDate FROM Steps ORDER BY CreatedDate)
                                           FROM ProcessInstance
                                           WHERE TargetObjectId IN :recordMap.keySet()
                                           ORDER BY CreatedDate DESC
                                          ];
        
        List<ApprovalStepWrapper> results = new List<ApprovalStepWrapper>();
        
        for (ProcessInstance instance : instances) {
            SObject rec = recordMap.get(instance.TargetObjectId);
            String name = (String)rec.get('Name');
            Boolean l1 = (Boolean)rec.get('L1_Approved__c');
            Boolean l2 = (Boolean)rec.get('L2_Approved__c');
            Boolean active = (Boolean)rec.get('Active__c');
            
            for (ProcessInstanceStep step : instance.Steps) {
                results.add(new ApprovalStepWrapper(
                    instance.Id,
                    name,
                    l1, l2, active,
                    instance.CreatedDate,
                    instance.Status,
                    step.Actor != null ? step.Actor.Name : '',
                    step.StepStatus,
                    step.Comments,
                    step.CreatedDate
                ));
            }
        }
        
        return results;
    }
    
    public class ApprovalStepWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String recordName;
        @AuraEnabled public Boolean l1Approved;
        @AuraEnabled public Boolean l2Approved;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Datetime submissionDate;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String approverName;
        @AuraEnabled public String stepStatus;
        @AuraEnabled public String comments;
        @AuraEnabled public Datetime actionDate;
        
        public ApprovalStepWrapper(Id id, String recordName, Boolean l1Approved, Boolean l2Approved, Boolean isActive,
                                   Datetime submissionDate, String approvalStatus,
                                   String approverName, String stepStatus, String comments, Datetime actionDate) {
                                       this.id = id;
                                       this.recordName = recordName;
                                       this.l1Approved = l1Approved;
                                       this.l2Approved = l2Approved;
                                       this.isActive = isActive;
                                       this.submissionDate = submissionDate;
                                       this.approvalStatus = approvalStatus;
                                       this.approverName = approverName;
                                       this.stepStatus = stepStatus;
                                       this.comments = comments;
                                       this.actionDate = actionDate;
                                   }
    }
    public class ReportLink {
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        
        public ReportLink(String name, String url) {
            this.name = name;
            this.url = url;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ReportLink> getReportLinks() {
        return new List<ReportLink>{
            new ReportLink('Credit Notes Report', '/lightning/r/Report/00OBl000000owFJMAY/view'),
                new ReportLink('Final Inventory Report', '/lightning/r/Report/00OBl000000mccTMAQ/view'),
                new ReportLink('Sales Report', '/lightning/r/Report/00OBl000000ovr8MAA/view'),
                new ReportLink('Open PO Report', '/lightning/r/Report/00OBl000000q6e3MAA/view'),
                new ReportLink('Open SO Report', '/lightning/r/Report/00OBl000000qiOLMAY/view')
                };
                    }
    public class NonMovingInventoryDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String brand;
        @AuraEnabled public String materialName;
        @AuraEnabled public String size;
        @AuraEnabled public String currentWH;
        @AuraEnabled public Integer stockQty;
        @AuraEnabled public Date lastUsedDate;
        @AuraEnabled public Integer daysIdle;
        @AuraEnabled public String recommendedWH;
        @AuraEnabled public String recommendedAction;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<NonMovingInventoryDTO>> getNonMovingInventory() {
        Id userId = UserInfo.getUserId();
        User currentUser = [SELECT Id, Profile.Name FROM User WHERE Id = :userId LIMIT 1];
        
        List<Warehouse__c> targetWarehouses;
        
        if (currentUser.Profile.Name == 'System Administrator') {
            targetWarehouses = [SELECT Id, Name FROM Warehouse__c];
        } else {
            Id curAccountId = [SELECT Id FROM Account WHERE Business_Owner__c = :userId LIMIT 1].Id;
            targetWarehouses = [SELECT Id, Name FROM Warehouse__c WHERE Account__c = :curAccountId];
        }
        
        Set<Id> warehouseIds = new Set<Id>();
        for (Warehouse__c wh : targetWarehouses) {
            warehouseIds.add(wh.Id);
        }
        
        List<Warehouse_Product__c> warehouseProducts = [
            SELECT Id, Zydus_Product__c, Zydus_Product__r.Name, Last_Usage_Date__c,
            Warehouse__c, Warehouse__r.Name,
            Zydus_Product__r.Brand__c, Zydus_Product__r.Size__c, Zydus_Product__r.Brand__r.Name
            FROM Warehouse_Product__c
            WHERE Warehouse__c IN :warehouseIds
        ];
        
        Set<Id> warehouseProductIds = new Set<Id>();
        Set<Id> zydusProductIds = new Set<Id>();
        for (Warehouse_Product__c wp : warehouseProducts) {
            warehouseProductIds.add(wp.Id);
            zydusProductIds.add(wp.Zydus_Product__c);
        }
        
        Map<Id, List<Warehouse_Product_Line_Items__c>> productToLineItemsMap = new Map<Id, List<Warehouse_Product_Line_Items__c>>();
        List<Warehouse_Product_Line_Items__c> freeLineItems = [
            SELECT Id, CreatedDate, Warehouse__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Status__c = 'Available' AND Warehouse__c IN :warehouseProductIds
        ];
        
        for (Warehouse_Product_Line_Items__c item : freeLineItems) {
            if (!productToLineItemsMap.containsKey(item.Warehouse__c)) {
                productToLineItemsMap.put(item.Warehouse__c, new List<Warehouse_Product_Line_Items__c>());
            }
            productToLineItemsMap.get(item.Warehouse__c).add(item);
        }
        
        Map<Id, Map<Id, Integer>> productWarehouseConsumptionMap = new Map<Id, Map<Id, Integer>>();
        List<Warehouse_Product_Line_Items__c> allConsumed = [
            SELECT Id, Warehouse__r.Zydus_Product__c, Connected_Warehouse__c
            FROM Warehouse_Product_Line_Items__c
            WHERE Status__c = 'Consumed' AND Warehouse__r.Zydus_Product__c IN :zydusProductIds
        ];
        
        Set<Id> recommendedWhIds = new Set<Id>();
        for (Warehouse_Product_Line_Items__c item : allConsumed) {
            Id productId = item.Warehouse__r.Zydus_Product__c;
            Id whId = item.Connected_Warehouse__c;
            if (whId == null) continue;
            
            if (!productWarehouseConsumptionMap.containsKey(productId)) {
                productWarehouseConsumptionMap.put(productId, new Map<Id, Integer>());
            }
            Map<Id, Integer> whMap = productWarehouseConsumptionMap.get(productId);
            whMap.put(whId, whMap.containsKey(whId) ? whMap.get(whId) + 1 : 1);
            recommendedWhIds.add(whId);
        }
        
        Map<Id, Warehouse__c> warehouseLookup = new Map<Id, Warehouse__c>(
            [SELECT Id, Name FROM Warehouse__c WHERE Id IN :recommendedWhIds]
        );
        
        Map<String, List<NonMovingInventoryDTO>> groupedResults = new Map<String, List<NonMovingInventoryDTO>>();
        
        for (Warehouse_Product__c wp : warehouseProducts) {
            NonMovingInventoryDTO dto = new NonMovingInventoryDTO();
            dto.id = wp.Id;
            dto.brand = wp.Zydus_Product__r.Brand__r.Name;
            dto.materialName = wp.Zydus_Product__r.Name;
            dto.size = wp.Zydus_Product__r.Size__c;
            dto.currentWH = wp.Warehouse__r.Name;
            dto.lastUsedDate = wp.Last_Usage_Date__c;
            
            List<Warehouse_Product_Line_Items__c> freeItems = productToLineItemsMap.get(wp.Id);
            dto.stockQty = (freeItems != null) ? freeItems.size() : 0;
            
            if (dto.stockQty == 0) {
                dto.daysIdle = null;
                dto.recommendedWH = null;
                dto.recommendedAction = 'No recommendation – out of stock';
                
                if (!groupedResults.containsKey('No Stock')) {
                    groupedResults.put('No Stock', new List<NonMovingInventoryDTO>());
                }
                groupedResults.get('No Stock').add(dto);
                continue;
            }
            
            if (freeItems != null && !freeItems.isEmpty()) {
                Integer maxIdle = 0;
                for (Warehouse_Product_Line_Items__c item : freeItems) {
                    Date createdDateOnly = item.CreatedDate.dateGmt();
                    Integer days = createdDateOnly.daysBetween(Date.today());
                    if (days > maxIdle) {
                        maxIdle = days;
                    }
                }
                dto.daysIdle = maxIdle;
            }
            
            Map<Id, Integer> whConsumption = productWarehouseConsumptionMap.get(wp.Zydus_Product__c);
            Id recommendedWhId;
            Integer maxConsumed = 0;
            if (whConsumption != null) {
                for (Id whId : whConsumption.keySet()) {
                    Integer count = whConsumption.get(whId);
                    if (count > maxConsumed) {
                        maxConsumed = count;
                        recommendedWhId = whId;
                    }
                }
            }
            
            String recommendedWhName;
            if (recommendedWhId != null && warehouseLookup.containsKey(recommendedWhId)) {
                recommendedWhName = warehouseLookup.get(recommendedWhId).Name;
                dto.recommendedWH = recommendedWhName;
            }
            
            String actionGroup;
            if (wp.Last_Usage_Date__c != null) {
                Integer daysSinceLastUsed = Date.today().daysBetween(wp.Last_Usage_Date__c);
                if (daysSinceLastUsed <= 90) {
                    actionGroup = 'Suggestion';
                } else if (daysSinceLastUsed <= 180) {
                    actionGroup = 'Recommended';
                } else {
                    actionGroup = 'Highly Recommend';
                }
            } else {
                actionGroup = 'No Usage Data';
            }
            
            if (recommendedWhName != null) {
                if (recommendedWhName != wp.Warehouse__r.Name) {
                    dto.recommendedAction = actionGroup + ' – Consider transferring to ' + recommendedWhName + ' for better utilization.';
                } else {
                    dto.recommendedAction = actionGroup + ' – Product is currently in the optimal warehouse.';
                }
            } else {
                dto.recommendedAction = actionGroup + ' – No alternate warehouse recommendation found.';
            }
            
            if (!groupedResults.containsKey(actionGroup)) {
                groupedResults.put(actionGroup, new List<NonMovingInventoryDTO>());
            }
            groupedResults.get(actionGroup).add(dto);
        }
        
        return groupedResults;
    }
    public class SerialMovementResult {
        @AuraEnabled public List<SerialMovementRow> records;
        @AuraEnabled public Integer totalRecords;
        
        public SerialMovementResult(List<SerialMovementRow> records, Integer totalRecords) {
            this.records = records;
            this.totalRecords = totalRecords;
        }
    }
    
    public class SerialMovementRow {
        @AuraEnabled public String serialNumber;
        @AuraEnabled public String batchNumber;
        @AuraEnabled public String brand;
        @AuraEnabled public String zydusProduct;
        
        @AuraEnabled public String zydusId;
        @AuraEnabled public String zydusName;
        @AuraEnabled public Decimal zydusAmount;
        @AuraEnabled public Date zydusInvoiceDate;
        @AuraEnabled public Decimal zydusToSuperMargin;
        @AuraEnabled public Decimal zydusToSuperMarginPercent;
        
        @AuraEnabled public String superDistributorId;
        @AuraEnabled public String superDistributorName;
        @AuraEnabled public Decimal superDistributorAmount;
        @AuraEnabled public Date superDistributorInvoiceDate;
        @AuraEnabled public Decimal superToNextMargin;
        @AuraEnabled public Decimal superToNextMarginPercent;
        
        @AuraEnabled public String distributorId;
        @AuraEnabled public String distributorName;
        @AuraEnabled public Decimal distributorAmount;
        @AuraEnabled public Date distributorInvoiceDate;
        @AuraEnabled public Decimal distributorToNextMargin;
        @AuraEnabled public Decimal distributorToNextMarginPercent;
        
        @AuraEnabled public String subDistributorId;
        @AuraEnabled public String subDistributorName;
        @AuraEnabled public Decimal subDistributorAmount;
        @AuraEnabled public Date subDistributorInvoiceDate;
        @AuraEnabled public Decimal subToHospitalMargin;
        @AuraEnabled public Decimal subToHospitalMarginPercent;
        
        @AuraEnabled public String hospitalId;
        @AuraEnabled public String hospitalName;
        @AuraEnabled public Decimal hospitalAmount;
        @AuraEnabled public Date hospitalInvoiceDate;
        
        @AuraEnabled public String zydusAmountFormatted;
        @AuraEnabled public String zydusToSuperMarginFormatted;
        @AuraEnabled public String zydusToSuperMarginPercentFormatted;
        
        @AuraEnabled public String superDistributorAmountFormatted;
        @AuraEnabled public String superToNextMarginFormatted;
        @AuraEnabled public String superToNextMarginPercentFormatted;
        
        @AuraEnabled public String distributorAmountFormatted;
        @AuraEnabled public String distributorToNextMarginFormatted;
        @AuraEnabled public String distributorToNextMarginPercentFormatted;
        
        @AuraEnabled public String subDistributorAmountFormatted;
        @AuraEnabled public String subToHospitalMarginFormatted;
        @AuraEnabled public String subToHospitalMarginPercentFormatted;
        
        @AuraEnabled public Decimal superDistributorPurchasePrice;
        @AuraEnabled public Decimal distributorPurchasePrice;
        @AuraEnabled public Decimal subDistributorPurchasePrice;
        @AuraEnabled public Decimal hospitalPurchasePrice;
        
        @AuraEnabled public String superDistributorPurchasePriceFormatted;
        @AuraEnabled public String distributorPurchasePriceFormatted;
        @AuraEnabled public String subDistributorPurchasePriceFormatted;
        @AuraEnabled public String hospitalPurchasePriceFormatted;
        
        @AuraEnabled public String zydusBillToName;
        @AuraEnabled public String superDistributorBillToName;
        @AuraEnabled public String distributorBillToName;
        @AuraEnabled public String subDistributorBillToName;
    }
    @AuraEnabled(cacheable=true)
    public static SerialMovementResult getSerialMovementReport(Integer pageSize, Integer pageNumber, String dateRangeOption) {
        Integer offset = (pageNumber - 1) * pageSize;
        Date startDate;
        
        if (dateRangeOption == '30') {
            startDate = Date.today().addDays(-30);
        } else if (dateRangeOption == '60') {
            startDate = Date.today().addDays(-60);
        } else if (dateRangeOption == '90') {
            startDate = Date.today().addDays(-90);
        }
        
        // 1️⃣ Get paginated unique serial numbers
        String serialQuery = 'SELECT Serial_Number__c FROM Invoice_Product_Line_Item__c WHERE Serial_Number__c != null';
        if (startDate != null) {
            serialQuery += ' AND Invoice__r.InvoiceDate__c >= :startDate';
        }
        serialQuery += ' GROUP BY Serial_Number__c ORDER BY MAX(Invoice__r.InvoiceDate__c) DESC LIMIT :pageSize OFFSET :offset';
        
        List<AggregateResult> serialResults = Database.query(serialQuery);
        Set<String> serialSet = new Set<String>();
        for (AggregateResult ar : serialResults) {
            serialSet.add((String)ar.get('Serial_Number__c'));
        }
        
        if (serialSet.isEmpty()) {
            return new SerialMovementResult(new List<SerialMovementRow>(), 0);
        }
        
        // 2️⃣ Query all records for those serials
        String baseQuery = 'SELECT Id, Serial_Number__c, Before_Tax_Amount__c, Brand__c, Batch_Number__c, ' +
            'Zydus_Product__r.Material_Description__c, ' +
            'Invoice__r.Id, Invoice__r.InvoiceDate__c, ' +
            'Invoice__r.Consignor_Dealer__c, Invoice__r.Consignor_Dealer__r.Name, Invoice__r.Consignor_Dealer__r.RecordType.DeveloperName, ' +
            'Invoice__r.Consignee_Dealer__c, Invoice__r.Consignee_Dealer__r.Name, Invoice__r.Consignee_Dealer__r.RecordType.DeveloperName, ' +
            'Invoice__r.Hospital__c, Invoice__r.Hospital__r.Name ' +
            'FROM Invoice_Product_Line_Item__c ' +
            'WHERE Serial_Number__c IN :serialSet ' +
            'ORDER BY Invoice__r.InvoiceDate__c DESC';
        
        List<Invoice_Product_Line_Item__c> items = Database.query(baseQuery);
        
        // 3️⃣ Build map of SerialMovementRow
        Map<String, SerialMovementRow> serialMap = new Map<String, SerialMovementRow>();
        
        for (Invoice_Product_Line_Item__c item : items) {
            if (String.isBlank(item.Serial_Number__c)) continue;
            
            String serial = item.Serial_Number__c;
            if (!serialMap.containsKey(serial)) {
                SerialMovementRow row = new SerialMovementRow();
                row.serialNumber = serial;
                row.batchNumber = item.Batch_Number__c;
                row.brand = item.Brand__c;
                row.zydusProduct = item.Zydus_Product__r != null ? item.Zydus_Product__r.Material_Description__c : null;
                serialMap.put(serial, row);
            }
            
            SerialMovementRow row = serialMap.get(serial);
            Invoice__c inv = item.Invoice__r;
            
            String consignorRole = inv.Consignor_Dealer__r != null ? inv.Consignor_Dealer__r.RecordType.DeveloperName : null;
            String consigneeRole = inv.Consignee_Dealer__r != null ? inv.Consignee_Dealer__r.RecordType.DeveloperName : null;
            
            if (consignorRole == 'Zydus') {
                row.zydusId = inv.Consignor_Dealer__c;
                row.zydusName = inv.Consignor_Dealer__r.Name;
                row.zydusAmount = item.Before_Tax_Amount__c;
                row.zydusInvoiceDate = inv.InvoiceDate__c;
                row.zydusBillToName = inv.Consignee_Dealer__r != null ? inv.Consignee_Dealer__r.Name : null;
            }
            
            if (consignorRole == 'Super_Distributor' && (consigneeRole == 'Distributor' || consigneeRole == 'Sub_Distributor' || inv.Hospital__c != null)) {
                row.superDistributorId = inv.Consignor_Dealer__c;
                row.superDistributorName = inv.Consignor_Dealer__r.Name;
                row.superDistributorAmount = item.Before_Tax_Amount__c;
                row.superDistributorInvoiceDate = inv.InvoiceDate__c;
                row.superDistributorBillToName = inv.Consignee_Dealer__r != null ? inv.Consignee_Dealer__r.Name : inv.Hospital__r != null ? inv.Hospital__r.Name : null;
            }
            if (consigneeRole == 'Super_Distributor' && consignorRole == 'Zydus') {
                row.superDistributorPurchasePrice = item.Before_Tax_Amount__c;
            }
            
            if (consignorRole == 'Distributor' && (consigneeRole == 'Sub_Distributor' || inv.Hospital__c != null)) {
                row.distributorId = inv.Consignor_Dealer__c;
                row.distributorName = inv.Consignor_Dealer__r.Name;
                row.distributorAmount = item.Before_Tax_Amount__c;
                row.distributorInvoiceDate = inv.InvoiceDate__c;
                row.distributorBillToName = inv.Consignee_Dealer__r != null ? inv.Consignee_Dealer__r.Name : inv.Hospital__r != null ? inv.Hospital__r.Name : null;
            }
            if (consigneeRole == 'Distributor' && consignorRole == 'Super_Distributor') {
                row.distributorPurchasePrice = item.Before_Tax_Amount__c;
            }
            
            if (consignorRole == 'Sub_Distributor' && inv.Hospital__c != null) {
                row.subDistributorId = inv.Consignor_Dealer__c;
                row.subDistributorName = inv.Consignor_Dealer__r.Name;
                row.subDistributorAmount = item.Before_Tax_Amount__c;
                row.subDistributorInvoiceDate = inv.InvoiceDate__c;
                row.subDistributorBillToName = inv.Hospital__r != null ? inv.Hospital__r.Name : null;
            }
            if (consigneeRole == 'Sub_Distributor' && (consignorRole == 'Distributor' || consignorRole == 'Super_Distributor')) {
                row.subDistributorPurchasePrice = item.Before_Tax_Amount__c;
            }
        }
        
        // 4️⃣ Post-processing
        for (SerialMovementRow row : serialMap.values()) {
            row.zydusToSuperMargin = computeMargin(row.zydusAmount, row.superDistributorPurchasePrice);
            row.zydusToSuperMarginPercent = computeMarginPercent(row.superDistributorPurchasePrice, row.zydusAmount);
            
            row.superToNextMargin = computeMargin(row.superDistributorAmount, row.superDistributorPurchasePrice);
            row.superToNextMarginPercent = computeMarginPercent(row.superDistributorPurchasePrice, row.superDistributorAmount);
            
            row.distributorToNextMargin = computeMargin(row.distributorAmount, row.distributorPurchasePrice);
            row.distributorToNextMarginPercent = computeMarginPercent(row.distributorPurchasePrice, row.distributorAmount);
            
            row.subToHospitalMargin = computeMargin(row.subDistributorAmount, row.subDistributorPurchasePrice);
            row.subToHospitalMarginPercent = computeMarginPercent(row.subDistributorPurchasePrice, row.subDistributorAmount);
            
            row.zydusAmountFormatted = formatCurrency(row.zydusAmount);
            row.zydusToSuperMarginFormatted = formatCurrency(row.zydusToSuperMargin);
            row.zydusToSuperMarginPercentFormatted = formatPercent(row.zydusToSuperMarginPercent);
            
            row.superDistributorAmountFormatted = formatCurrency(row.superDistributorAmount);
            row.superToNextMarginFormatted = formatCurrency(row.superToNextMargin);
            row.superToNextMarginPercentFormatted = formatPercent(row.superToNextMarginPercent);
            
            row.distributorAmountFormatted = formatCurrency(row.distributorAmount);
            row.distributorToNextMarginFormatted = formatCurrency(row.distributorToNextMargin);
            row.distributorToNextMarginPercentFormatted = formatPercent(row.distributorToNextMarginPercent);
            
            row.subDistributorAmountFormatted = formatCurrency(row.subDistributorAmount);
            row.subToHospitalMarginFormatted = formatCurrency(row.subToHospitalMargin);
            row.subToHospitalMarginPercentFormatted = formatPercent(row.subToHospitalMarginPercent);
            
            row.superDistributorPurchasePriceFormatted = formatCurrency(row.superDistributorPurchasePrice);
            row.distributorPurchasePriceFormatted = formatCurrency(row.distributorPurchasePrice);
            row.subDistributorPurchasePriceFormatted = formatCurrency(row.subDistributorPurchasePrice);
            row.hospitalPurchasePriceFormatted = formatCurrency(row.hospitalPurchasePrice);
        }
        
        // 5️⃣ Total records (distinct serials)
        String countQuery = 'SELECT Serial_Number__c FROM Invoice_Product_Line_Item__c WHERE Serial_Number__c != null';
        if (startDate != null) {
            countQuery += ' AND Invoice__r.InvoiceDate__c >= :startDate';
        }
        countQuery += ' GROUP BY Serial_Number__c';
        
        List<AggregateResult> countResults = Database.query(countQuery);
        Integer totalRecords = countResults.size();
        
        
        return new SerialMovementResult(new List<SerialMovementRow>(serialMap.values()), totalRecords);
    }  
    
    private static Decimal computeMargin(Decimal sales, Decimal purchase) {
        return (sales != null && purchase != null) ? sales - purchase : null;
    }
    
    private static Decimal computeMarginPercent(Decimal purchase, Decimal sales) {
        return (sales != null && purchase != null && purchase != 0) ? ((sales - purchase) / purchase) * 100 : null;
    }
    
    private static String formatCurrency(Decimal amount) {
        return amount != null ? '₹' + String.valueOf(amount.setScale(2)) : '----';
    }
    
    private static String formatPercent(Decimal percent) {
        return percent != null ? String.valueOf(percent.setScale(2)) + '%' : '----';
    }
    
    public class HistoryWrapper {
        @AuraEnabled
        public Warehouse_Product_Line_Items__History historyRecord { get; set; }
        
        
        @AuraEnabled
        public String brand { get; set; }
        
        @AuraEnabled
        public String materialCode { get; set; }
        
        @AuraEnabled
        public String batchName { get; set; }
        
        @AuraEnabled
        public String serialNumber { get; set; }
        
        @AuraEnabled
        public String warehouseName { get; set; }
        
        @AuraEnabled
        public String warehouseAccoutRecordType { get; set;}
        
        @AuraEnabled
        public String warehouseId { get; set; }
        
        @AuraEnabled
        public String poName { get; set; }
        
        @AuraEnabled
        public String soName { get; set; }
        
        @AuraEnabled
        public String dcName { get; set; }
    }
    
    @AuraEnabled
    public static List<HistoryWrapper> getMaterialHistory() {
        Map<Id, Warehouse_Product_Line_Items__c> parentItemsMap = new Map<Id, Warehouse_Product_Line_Items__c>([
            SELECT Id, Connected_Warehouse__r.Name, Connected_Warehouse__r.Account__r.RecordType.Name, 
            Delivery_Challan_Line_Item__r.Delivery_Challan__r.Name, Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.Name,
            Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__r.Name,
            Warehouse__r.Zydus_Product__r.Brand__r.Name, Warehouse__r.Zydus_Product__r.SAP_Code__c,
            Batch_Number__c, Serial_Number__c
            FROM Warehouse_Product_Line_Items__c
        ]);
        
        if (parentItemsMap.isEmpty()) {
            return new List<HistoryWrapper>();
        }
        
        List<Warehouse_Product_Line_Items__History> historyList = [
            SELECT ParentId, Field, OldValue, NewValue, CreatedById, CreatedBy.Name, CreatedDate
            FROM Warehouse_Product_Line_Items__History
            WHERE ParentId IN :parentItemsMap.keySet()
            ORDER BY CreatedDate DESC
        ];
        
        List<HistoryWrapper> results = new List<HistoryWrapper>();
        for (Warehouse_Product_Line_Items__History hist : historyList) {
            HistoryWrapper wrap = new HistoryWrapper();
            wrap.historyRecord = hist;
            wrap.warehouseName = parentItemsMap.get(hist.ParentId)?.Connected_Warehouse__r.Name;
            wrap.warehouseId = parentItemsMap.get(hist.ParentId)?.Connected_Warehouse__c;
            wrap.warehouseAccoutRecordType = parentItemsMap.get(hist.ParentId)?.Connected_Warehouse__r.Account__r.RecordType.Name;
            wrap.poName = parentItemsMap.get(hist.ParentId)?.Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.New_Purchase_Order__r.Name;
            wrap.soName = parentItemsMap.get(hist.ParentId)?.Delivery_Challan_Line_Item__r.Delivery_Challan__r.Supply_Order__r.Name;
            wrap.dcName = parentItemsMap.get(hist.ParentId)?.Delivery_Challan_Line_Item__r.Delivery_Challan__r.Name;
            wrap.brand = parentItemsMap.get(hist.ParentId)?.Warehouse__r.Zydus_Product__r.Brand__r.Name;
            wrap.materialCode = parentItemsMap.get(hist.ParentId)?.Warehouse__r.Zydus_Product__r.SAP_Code__c;
            wrap.batchName = parentItemsMap.get(hist.ParentId)?.Batch_Number__c;
            wrap.serialNumber = parentItemsMap.get(hist.ParentId)?.Serial_Number__c;
            
            results.add(wrap);
        }
        return results;
    }
}