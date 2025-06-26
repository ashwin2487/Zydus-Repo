public class OpportunityOrderDetailUpdater implements Queueable {
    private Map<Id, Id> oppToOrderMap;

    public OpportunityOrderDetailUpdater(Map<Id, Id> oppToOrderMap) {
        this.oppToOrderMap = oppToOrderMap;
    }

    public void execute(QueueableContext context) {
        List<Opportunity> oppsToUpdate = [
            SELECT Id, Is_Order_Created__c, Linked_Order__c
            FROM Opportunity
            WHERE Id IN :oppToOrderMap.keySet()
        ];

        for (Opportunity opp : oppsToUpdate) {
            opp.Is_Order_Created__c = true;
            opp.Linked_Order__c = oppToOrderMap.get(opp.Id);
            
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}