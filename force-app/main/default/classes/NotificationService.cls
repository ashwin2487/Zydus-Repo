public class NotificationService {
    
    public static void sendEmail(List<String> toAddresses, String subject, String body) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);
        email.setSubject(subject);
        email.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
 
    public static void notifyUsers(Set<String> recipientsIds, String targetId, String title, String body) {

        CustomNotificationType notificationType = 
            [SELECT Id, DeveloperName 
             FROM CustomNotificationType 
             WHERE DeveloperName='Zydus_DMS_Notifications'];
        
        Messaging.CustomNotification notification = new Messaging.CustomNotification();


        notification.setTitle(title);
        notification.setBody(body);

        notification.setNotificationTypeId(notificationType.Id);
        notification.setTargetId(targetId);
        
        try {
            notification.send(recipientsIds);
        }
        catch (Exception e) {
            System.debug('Problem sending notification: ' + e.getMessage());
        }
    }
}