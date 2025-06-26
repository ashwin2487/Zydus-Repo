trigger CreateOLIFromOpportunity on Opportunity (after insert) {
    
    List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();

    Map<Id, Id> oppIdToPBMap = new Map<Id, Id>();
    for (Opportunity opp : Trigger.new) {
        if (opp.Pricebook2Id != null) {
            oppIdToPBMap.put(opp.Id, opp.Pricebook2Id);
        }
    }

    if (!oppIdToPBMap.isEmpty()) {
        List<PricebookEntry> pbeList = [
            SELECT Id, Pricebook2Id, Product2Id, UnitPrice, Minimum_Order_Quantity_MOQ__c
            FROM PricebookEntry
            WHERE Pricebook2Id IN :oppIdToPBMap.values()
            AND IsActive = true
        ];

        Map<Id, List<PricebookEntry>> pbToPBEMap = new Map<Id, List<PricebookEntry>>();
        for (PricebookEntry pbe : pbeList) {
            if (!pbToPBEMap.containsKey(pbe.Pricebook2Id)) {
                pbToPBEMap.put(pbe.Pricebook2Id, new List<PricebookEntry>());
            }
            pbToPBEMap.get(pbe.Pricebook2Id).add(pbe);
        }

        for (Opportunity opp : Trigger.new) {
            if (oppIdToPBMap.containsKey(opp.Id)) {
                Id pbId = opp.Pricebook2Id;
                if (pbToPBEMap.containsKey(pbId)) {
                    for (PricebookEntry pbe : pbToPBEMap.get(pbId)) {
                        OpportunityLineItem oli = new OpportunityLineItem(
                            OpportunityId = opp.Id,
                            Quantity = pbe.Minimum_Order_Quantity_MOQ__c,
                            PricebookEntryId = pbe.Id,
                            UnitPrice = pbe.UnitPrice,
                            SO_Status__c = 'SO Pending',
                            Pending_Quantity__c = pbe.Minimum_Order_Quantity_MOQ__c
                        );
                        oliList.add(oli);
                    }
                }
            }
        }
    }

    if (!oliList.isEmpty()) {
        insert oliList;
    }
}