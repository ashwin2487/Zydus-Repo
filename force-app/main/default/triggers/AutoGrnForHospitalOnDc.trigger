trigger AutoGrnForHospitalOnDc on Delivery_Challan_Line_Item__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        AutoGrnForHospitalOnDcHandler.createGRNs(Trigger.new);
    }
}