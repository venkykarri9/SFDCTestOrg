@IsTest
private class ExpenseIntakeControllerTest {

    @TestSetup
    static void makeData() {
        List<Expense_Request__c> requests = new List<Expense_Request__c>();
        for (Integer i = 0; i < 200; i++) {
            Expense_Request__c r = new Expense_Request__c(
                Expense_Date__c = Date.today().addDays(-i),
                Expense_Type__c = 'Travel',
                Amount__c       = 100.00 + i
            );
            requests.add(r);
        }
        insert requests;
    }

    // -------------------------------------------------------------------------
    // getExpenseRequests — positive
    // -------------------------------------------------------------------------
    @IsTest
    static void testGetExpenseRequests_returnsRecords() {
        Test.startTest();
        List<Expense_Request__c> results = ExpenseIntakeController.getExpenseRequests();
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Expected at least one expense request to be returned.');
    }

    // -------------------------------------------------------------------------
    // getExpenseRequests — bulk (200 records inserted in @TestSetup)
    // -------------------------------------------------------------------------
    @IsTest
    static void testGetExpenseRequests_bulk() {
        Test.startTest();
        List<Expense_Request__c> results = ExpenseIntakeController.getExpenseRequests();
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Expected exactly 200 expense request records.');
    }

    // -------------------------------------------------------------------------
    // saveExpenseRequest — positive (insert)
    // -------------------------------------------------------------------------
    @IsTest
    static void testSaveExpenseRequest_insert() {
        Expense_Request__c newRecord = new Expense_Request__c(
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'Meals',
            Amount__c       = 55.00
        );

        Test.startTest();
        Expense_Request__c saved = ExpenseIntakeController.saveExpenseRequest(newRecord);
        Test.stopTest();

        System.assertNotEquals(null, saved.Id, 'Saved record should have an Id after upsert.');
    }

    // -------------------------------------------------------------------------
    // saveExpenseRequest — positive (update)
    // -------------------------------------------------------------------------
    @IsTest
    static void testSaveExpenseRequest_update() {
        Expense_Request__c existing = [
            SELECT Id, Amount__c
            FROM Expense_Request__c
            LIMIT 1
        ];
        existing.Amount__c = 999.99;

        Test.startTest();
        Expense_Request__c updated = ExpenseIntakeController.saveExpenseRequest(existing);
        Test.stopTest();

        Expense_Request__c reloaded = [
            SELECT Amount__c
            FROM Expense_Request__c
            WHERE Id = :updated.Id
        ];
        System.assertEquals(999.99, reloaded.Amount__c, 'Amount should be updated to 999.99.');
    }

    // -------------------------------------------------------------------------
    // saveExpenseRequest — negative (null record)
    // -------------------------------------------------------------------------
    @IsTest
    static void testSaveExpenseRequest_nullRecord() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ExpenseIntakeController.saveExpenseRequest(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'An AuraHandledException should be thrown for a null record.');
    }

    // -------------------------------------------------------------------------
    // deleteExpenseRequest — positive
    // -------------------------------------------------------------------------
    @IsTest
    static void testDeleteExpenseRequest_positive() {
        Expense_Request__c toDelete = [
            SELECT Id
            FROM Expense_Request__c
            LIMIT 1
        ];
        Id deletedId = toDelete.Id;

        Test.startTest();
        ExpenseIntakeController.deleteExpenseRequest(deletedId);
        Test.stopTest();

        List<Expense_Request__c> remaining = [
            SELECT Id
            FROM Expense_Request__c
            WHERE Id = :deletedId
        ];
        System.assertEquals(0, remaining.size(), 'Record should have been deleted.');
    }

    // -------------------------------------------------------------------------
    // deleteExpenseRequest — negative (null Id)
    // -------------------------------------------------------------------------
    @IsTest
    static void testDeleteExpenseRequest_nullId() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ExpenseIntakeController.deleteExpenseRequest(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'An AuraHandledException should be thrown when Id is null.');
    }
}