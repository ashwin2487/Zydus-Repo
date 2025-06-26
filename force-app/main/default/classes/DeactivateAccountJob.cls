global class DeactivateAccountJob implements Schedulable {

    global void execute(SchedulableContext sc) {
        List<Account> accs = [SELECT Id, Contact_Person_Email__c 
                              FROM Account 
                              WHERE Validity_of_Drug_Licence__c = :Date.today().addDays(-1) 
                              AND DL_Active__c = true];
        
        for (Account acc : accs) {
            acc.DL_Active__c = false;
        }
        
        if (!accs.isEmpty()) {
            update accs;
        }
    }

    public static void scheduleJob() {
        String cronExp = '0 0 0 * * ?'; 
        String jobName = 'DL_Deactivate_Account_Job';
        DeactivateAccountJob job = new DeactivateAccountJob();
        System.schedule(jobName, cronExp, job);
    }
}