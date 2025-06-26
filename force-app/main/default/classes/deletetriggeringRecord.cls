public class deletetriggeringRecord implements Queueable {
    private List<Id> toDeletedIds;
    
    public deletetriggeringRecord(List<Id> toDeletedIds) {
        this.toDeletedIds = toDeletedIds;
    }
    
    public void execute(QueueableContext context) {
        List<Zydus_Price_Book_Entry__c> toDel = [
            SELECT Id, RecordType.Name 
            FROM Zydus_Price_Book_Entry__c 
            WHERE Id IN :toDeletedIds
        ];
        List<Zydus_Price_Book_Entry__c> safeToDelete = new List<Zydus_Price_Book_Entry__c>();
        
        for (Zydus_Price_Book_Entry__c rec : toDel) {
            if (rec.RecordType.Name == 'Brand' || rec.RecordType.Name == 'SKU') {
                safeToDelete.add(rec);
            }
        }
        delete safeToDelete;
        
    }
}