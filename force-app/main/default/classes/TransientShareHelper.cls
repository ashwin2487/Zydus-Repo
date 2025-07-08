public class TransientShareHelper {
    
    public interface Runnable {
        void run();
    }
    
    /**
* Grants temporary edit access to a single record and revokes it after the update logic.
*
* @param recordId       The ID of the record to share
* @param userId         The user who should get temporary access
* @param objectName     The API name of the object (e.g., 'Delivery_Challan__c')
* @param updateLogic    The logic to execute while access is granted
*/
    public static void allowTemporaryEditAccess(Id recordId, Id userId, String objectName, Runnable updateLogic) {
        // Validate input
        if (recordId == null || userId == null || String.isBlank(objectName)) {
            throw new IllegalArgumentException('Invalid input parameters');
        }
        
        // Build the share object dynamically
        String shareObjectName = objectName + 'Share';
        SObject shareRecord;
        
        try {
            shareRecord = (SObject) Type.forName('Schema.SObjectType.' + shareObjectName).newInstance();
        } catch (Exception e) {
            throw new IllegalArgumentException('Cannot find share object for: ' + shareObjectName);
        }
        
        // Set share fields
        shareRecord.put(objectName + 'Id', recordId);
        shareRecord.put('UserOrGroupId', userId);
        shareRecord.put('AccessLevel', 'Edit');
        shareRecord.put('RowCause', 'Manual');

        insert shareRecord;
        
        try {
            updateLogic.run();
        } finally {
            delete shareRecord;
        }
    }
}