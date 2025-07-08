public class SchemaGlobalDescribeHelper {

    // Get object name from ID prefix
    public static String getObjectNameFromPrefix(String prefix) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        for (String s : gd.keySet()) {
            if (gd.get(s).getDescribe().getKeyPrefix() == prefix) {
                return s;
            }
        }
        return null;
    }

    // Check if object has a share object (i.e., __Share exists)
    public static Boolean hasShareObject(String objectName) {
        return Schema.getGlobalDescribe().containsKey(objectName + 'Share');
    }

    // Detect if object is controlled by master-detail relationship
    public static Boolean isMasterDetailControlled(String objectName) {
        Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
        Map<String, Schema.SObjectField> fields = objDescribe.fields.getMap();

        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult fieldDesc = fields.get(fieldName).getDescribe();
            if (fieldDesc.getType() == Schema.DisplayType.REFERENCE && fieldDesc.getRelationshipOrder() != null) {
                return true;
            }
        }
        return false;
    }

    // Get parent/master record IDs from child record IDs
    public static Map<Id, Id> getMasterRecordIds(String childObjectName, List<Id> childIds) {
        Map<Id, Id> result = new Map<Id, Id>();

        Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(childObjectName).getDescribe();
        Map<String, Schema.SObjectField> fields = objDescribe.fields.getMap();

        String masterField = null;

        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult fieldDesc = fields.get(fieldName).getDescribe();
            if (fieldDesc.getType() == Schema.DisplayType.REFERENCE && fieldDesc.getRelationshipOrder() != null) {
                masterField = fieldName;
                break;
            }
        }

        if (masterField != null) {
            String soql = 'SELECT Id, ' + masterField + ' FROM ' + childObjectName + ' WHERE Id IN :childIds';
            List<SObject> records = Database.query(soql);

            for (SObject rec : records) {
                result.put((Id)rec.get('Id'), (Id)rec.get(masterField));
            }
        }

        return result;
    }
}