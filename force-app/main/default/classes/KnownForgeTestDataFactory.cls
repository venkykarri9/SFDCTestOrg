@IsTest
public with sharing class KnownForgeTestDataFactory {

    public static SObject makeRecord(String objectApiName, Map<String, Object> overrides) {
        return makeRecordInternal(objectApiName, overrides == null ? new Map<String, Object>() : overrides, new Set<String>());
    }

    public static SObject insertRecord(String objectApiName, Map<String, Object> overrides) {
        SObject record = makeRecord(objectApiName, overrides);
        insert record;
        return record;
    }

    private static SObject makeRecordInternal(String objectApiName, Map<String, Object> overrides, Set<String> recursionGuard) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        System.assert(globalDescribe.containsKey(objectApiName), 'Unknown object for test factory: ' + objectApiName);

        if (recursionGuard.contains(objectApiName)) {
            return globalDescribe.get(objectApiName).newSObject();
        }
        recursionGuard.add(objectApiName);

        Schema.SObjectType sObjectType = globalDescribe.get(objectApiName);
        Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
        SObject record = sObjectType.newSObject();

        applyDefaults(record, describeResult, recursionGuard);
        applyOverrides(record, overrides);

        recursionGuard.remove(objectApiName);
        return record;
    }

    private static void applyDefaults(SObject record, Schema.DescribeSObjectResult describeResult, Set<String> recursionGuard) {
        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            if (record.get(fieldName) != null || fieldName == 'Id') {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            if (!fieldDescribe.isCreateable() || fieldDescribe.isCalculated() || fieldDescribe.isAutoNumber()) {
                continue;
            }
            if (fieldDescribe.isDefaultedOnCreate()) {
                continue;
            }

            Boolean shouldSet = !fieldDescribe.isNillable() || fieldName == 'Name';
            if (!shouldSet) {
                continue;
            }

            applyDefaultValue(record, fieldName, fieldDescribe, recursionGuard);
        }
    }

    private static void applyDefaultValue(SObject record, String fieldName, Schema.DescribeFieldResult fieldDescribe, Set<String> recursionGuard) {
        Schema.DisplayType displayType = fieldDescribe.getType();

        if (fieldName == 'Name' && displayType == Schema.DisplayType.String) {
            record.put(fieldName, record.getSObjectType().getDescribe().getName() + ' Test');
            return;
        }
        if (displayType == Schema.DisplayType.String
            || displayType == Schema.DisplayType.TextArea
            || displayType == Schema.DisplayType.EncryptedString
            || displayType == Schema.DisplayType.Email
            || displayType == Schema.DisplayType.Phone
            || displayType == Schema.DisplayType.Url) {
            record.put(fieldName, 'Test ' + fieldName);
            return;
        }
        if (displayType == Schema.DisplayType.Base64) {
            record.put(fieldName, Blob.valueOf('KnownForge test payload'));
            return;
        }
        if (displayType == Schema.DisplayType.Boolean) {
            record.put(fieldName, true);
            return;
        }
        if (displayType == Schema.DisplayType.Date) {
            record.put(fieldName, Date.today());
            return;
        }
        if (displayType == Schema.DisplayType.DateTime) {
            record.put(fieldName, System.now());
            return;
        }
        if (displayType == Schema.DisplayType.Time) {
            record.put(fieldName, Time.newInstance(9, 0, 0, 0));
            return;
        }
        if (displayType == Schema.DisplayType.Currency
            || displayType == Schema.DisplayType.Double
            || displayType == Schema.DisplayType.Percent) {
            record.put(fieldName, 1.0);
            return;
        }
        if (displayType == Schema.DisplayType.Integer
            || displayType == Schema.DisplayType.Long) {
            record.put(fieldName, 1);
            return;
        }
        if (displayType == Schema.DisplayType.Picklist) {
            List<Schema.PicklistEntry> values = fieldDescribe.getPicklistValues();
            for (Schema.PicklistEntry value : values) {
                if (value.isActive()) {
                    record.put(fieldName, value.getValue());
                    return;
                }
            }
            return;
        }
        if (displayType == Schema.DisplayType.MultiPicklist) {
            List<Schema.PicklistEntry> values = fieldDescribe.getPicklistValues();
            List<String> activeValues = new List<String>();
            for (Schema.PicklistEntry value : values) {
                if (value.isActive()) {
                    activeValues.add(value.getValue());
                }
                if (activeValues.size() == 2) {
                    break;
                }
            }
            if (!activeValues.isEmpty()) {
                record.put(fieldName, String.join(activeValues, ';'));
            }
            return;
        }
        if (displayType == Schema.DisplayType.Reference) {
            List<Schema.SObjectType> refs = fieldDescribe.getReferenceTo();
            if (!refs.isEmpty()) {
                String parentObjectApi = refs[0].getDescribe().getName();
                if (!recursionGuard.contains(parentObjectApi)) {
                    SObject parent = makeRecordInternal(parentObjectApi, new Map<String, Object>(), recursionGuard);
                    insert parent;
                    record.put(fieldName, parent.get('Id'));
                }
            }
        }
    }

    private static void applyOverrides(SObject record, Map<String, Object> overrides) {
        if (overrides == null) {
            return;
        }
        for (String fieldName : overrides.keySet()) {
            record.put(fieldName, overrides.get(fieldName));
        }
    }
}