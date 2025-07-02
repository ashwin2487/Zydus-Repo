public class EnqueueBrandPriceBookBatch implements Queueable {
    private List<Id> entryIds;

    public EnqueueBrandPriceBookBatch(List<Id> entryIds) {
        this.entryIds = entryIds;
    }

    public void execute(QueueableContext context) {
        Database.executeBatch(new BatchBrandPriceBookProcessor(entryIds), 50);
    }
}