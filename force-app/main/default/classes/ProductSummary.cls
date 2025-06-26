public class ProductSummary {
    @AuraEnabled public Id productId;
    @AuraEnabled public String productName;
    @AuraEnabled public Decimal free = 0;
    @AuraEnabled public Decimal inTransit = 0;
    @AuraEnabled public Decimal consumable = 0;
    @AuraEnabled public Decimal damaged = 0;
    @AuraEnabled public Decimal expired = 0;
    @AuraEnabled public Decimal aboutToExpire = 0;

    public ProductSummary(Id id, String name) {
        this.productId = id;
        this.productName = name;
    }
}