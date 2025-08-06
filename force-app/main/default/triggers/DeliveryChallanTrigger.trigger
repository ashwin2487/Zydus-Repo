trigger DeliveryChallanTrigger on Delivery_Challan__c  (after insert) {
    DeliveryChallanTriggerHandler.shareChallans(Trigger.new);
}