trigger AccountHospitalSharing on Account_Hospital__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        AccountHospitalSharingHandler.createHospitalShare(Trigger.new);
    }
}