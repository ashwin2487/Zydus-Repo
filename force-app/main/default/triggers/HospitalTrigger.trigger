trigger HospitalTrigger on Hospital__c (After Update) {
	if (Trigger.isAfter && Trigger.isUpdate) {
        HospitalTriggerHandler.createContact(Trigger.new, Trigger.oldMap);
    }
}