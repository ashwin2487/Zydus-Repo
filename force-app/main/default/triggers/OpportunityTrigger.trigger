trigger OpportunityTrigger on Opportunity (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityTriggerHandler.linkContractToOppty(Trigger.new, Trigger.oldMap);
    }
}