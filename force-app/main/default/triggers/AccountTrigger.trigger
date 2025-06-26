trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            AccountTriggerHandler.validateAccountCreation(Trigger.new);
        }
        if (Trigger.isUpdate) {
            AccountTriggerHandler.preventBusinessOwnerCreditLimitChange(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        AccountTriggerHandler.createContactAndUser(Trigger.new, Trigger.oldMap);
        AccountTriggerHandler.createContract(Trigger.new, Trigger.oldMap);
    }
}