public class PriceBookRolloverScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        Date today = Date.today();

        List<Zydus_Price_Book__c> expiredBooks = [
            SELECT Id, Start_Date__c, End_Date__c, IsActive__c
            FROM Zydus_Price_Book__c
            WHERE End_Date__c < :today
            AND IsActive__c = TRUE
        ];

        for (Zydus_Price_Book__c pb : expiredBooks) {
            List<Zydus_Price_Book__c> newerBooks = [
                SELECT Id FROM Zydus_Price_Book__c
                WHERE Start_Date__c > :pb.End_Date__c
                AND IsActive__c = TRUE
                ORDER BY Start_Date__c ASC LIMIT 1
            ];

            if (newerBooks.isEmpty()) {
                pb.End_Date__c = today.addDays(90); 
                pb.IsActive__c = true;
            } else {
                pb.IsActive__c = false;
            }
        }

        if (!expiredBooks.isEmpty()) {
            update expiredBooks;
        }
    }
}