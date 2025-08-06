trigger CreditNoteTrigger on Credit_Note__c  (after insert) {
    CreditNoteHandler.shareCreditNotes(Trigger.new);
}