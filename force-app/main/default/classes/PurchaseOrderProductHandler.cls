public class PurchaseOrderProductHandler {
    public static void validateUpdatePermission(List<Purchase_Order_Product__c> newList, Map<Id, Purchase_Order_Product__c> oldMap) {
        Set<Id> purchaseOrderIds = new Set<Id>();

        for (Purchase_Order_Product__c pop : newList) {
            if (pop.Purchase_Order__c != null) {
                purchaseOrderIds.add(pop.Purchase_Order__c);
            }
        }

        Map<Id, Purchase_Order__c> relatedPOMap = new Map<Id, Purchase_Order__c>(
            [SELECT Id, StageName__c FROM Purchase_Order__c WHERE Id IN :purchaseOrderIds]
        );

        for (Purchase_Order_Product__c pop : newList) {
            Purchase_Order__c relatedPO = relatedPOMap.get(pop.Purchase_Order__c);
            if (relatedPO != null && relatedPO.StageName__c != 'Draft Purchase Order' && pop.Quantity__c != oldMap.get(pop.Id).Quantity__c) {
                pop.addError('Editing is only allowed in Draft Purchase Order stage.');
            }
        }
    }
}