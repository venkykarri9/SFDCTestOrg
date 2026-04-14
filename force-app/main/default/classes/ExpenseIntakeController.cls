public with sharing class ExpenseIntakeController {

    /**
     * Retrieves a list of Expense_Request__c records visible to the current user.
     * @return List<Expense_Request__c>
     */
    @AuraEnabled(cacheable=true)
    public static List<Expense_Request__c> getExpenseRequests() {
        return [
            SELECT Id,
                   Name,
                   Expense_Date__c,
                   Expense_Type__c,
                   Amount__c
            FROM Expense_Request__c
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Saves a new or updated Expense_Request__c record.
     * @param record  The Expense_Request__c record to upsert.
     * @return Expense_Request__c  The saved record.
     */
    @AuraEnabled
    public static Expense_Request__c saveExpenseRequest(Expense_Request__c record) {
        if (record == null) {
            throw new AuraHandledException('Expense request record cannot be null.');
        }
        try {
            upsert record;
            return record;
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to save expense request: ' + e.getMessage());
        }
    }

    /**
     * Deletes an Expense_Request__c record by Id.
     * @param recordId  The Id of the record to delete.
     */
    @AuraEnabled
    public static void deleteExpenseRequest(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id cannot be null.');
        }
        try {
            Expense_Request__c toDelete = new Expense_Request__c(Id = recordId);
            delete toDelete;
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to delete expense request: ' + e.getMessage());
        }
    }
}