public with sharing class RecordSharingUtilityBulk {

    public static void shareRecords(List<Id> recordIds, Set<Id> userIdsToShareWith) {
        if (recordIds.isEmpty() || userIdsToShareWith.isEmpty()) {
            throw new IllegalArgumentException('recordIds and userIdsToShareWith cannot be empty');
        }

        Map<String, List<Id>> recordsByObject = new Map<String, List<Id>>();

        for (Id recordId : recordIds) {
            String prefix = String.valueOf(recordId).substring(0, 3);
            String objectName = SchemaGlobalDescribeHelper.getObjectNameFromPrefix(prefix);
            if (objectName != null) {
                if (!recordsByObject.containsKey(objectName)) {
                    recordsByObject.put(objectName, new List<Id>());
                }
                recordsByObject.get(objectName).add(recordId);
            }
        }

        List<SObject> allShares = new List<SObject>();

        for (String objectName : recordsByObject.keySet()) {
            List<Id> ids = recordsByObject.get(objectName);

            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult describe = sObjType.getDescribe();

            if (!describe.isCustom() || !SchemaGlobalDescribeHelper.hasShareObject(objectName)) {
                continue;
            }

            Boolean isMasterDetail = SchemaGlobalDescribeHelper.isMasterDetailControlled(objectName);

            Map<Id, Id> masterRecordMap = new Map<Id, Id>();

            if (isMasterDetail) {
                masterRecordMap = SchemaGlobalDescribeHelper.getMasterRecordIds(objectName, ids);
                objectName = SchemaGlobalDescribeHelper.getObjectNameFromPrefix(String.valueOf(masterRecordMap.values()[0]).substring(0, 3));
            }

            for (Id recId : ids) {
                Id targetId = isMasterDetail ? masterRecordMap.get(recId) : recId;

                for (Id userId : userIdsToShareWith) {
                    String shareObjectName = objectName + 'Share';
                    SObject shareRecord = (SObject) Type.forName('Schema.SObjectType.' + shareObjectName).newInstance();
                    shareRecord.put(objectName + 'Id', targetId);
                    shareRecord.put('UserOrGroupId', userId);
                    shareRecord.put('AccessLevel', 'Edit');
                    shareRecord.put('RowCause', 'Manual');
                    allShares.add(shareRecord);
                }
            }
        }

        if (!allShares.isEmpty()) {
            try {
                insert allShares;
            } catch (DmlException e) {
                System.debug('Sharing insert failed: ' + e.getMessage());
            }
        }
    }
}