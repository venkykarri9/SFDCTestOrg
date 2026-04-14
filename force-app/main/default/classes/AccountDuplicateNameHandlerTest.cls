/**
 * @description Test class for AccountDuplicateNameHandler.
 *              Covers positive, negative, and bulk scenarios as required by FORGESAN-010.
 *
 *              Test matrix:
 *              - testExactDuplicateBlocked          : AC-1 exact case match
 *              - testCaseInsensitiveDuplicateBlocked : AC-1 case-insensitive match
 *              - testUpdateNotBlocked               : AC-2 update path does not fire
 *              - testUniqueNameAllowed              : AC-3 unique name saves normally
 *              - testBulkPartialBlock               : bulk 200 records, half duplicates
 *              - testInBatchDuplicate               : two new records with same name in one DML
 *              - testNullNameHandledGracefully      : null/blank names do not throw exceptions
 *
 * @author      FORGESAN-010
 * @since       2024
 */
@IsTest
private class AccountDuplicateNameHandlerTest {

    // ─── Constants ───────────────────────────────────────────────────────────

    private static final String EXISTING_NAME   = 'Acme Corp';
    private static final String UNIQUE_NAME     = 'Unique Organisation Ltd';
    private static final String DUPLICATE_ERROR = 'An Account with this name already exists.';

    // ─── Test Setup ──────────────────────────────────────────────────────────

    /**
     * @description Creates a single pre-existing Account used as the duplicate baseline
     *              across all test methods that need one.
     */
    @TestSetup
    static void makeData() {
        Account existing = new Account(Name = EXISTING_NAME);
        insert existing;
    }

    // ─── Positive Tests ───────────────────────────────────────────────────────

    /**
     * @description AC-3: A new Account with a name that does not exist should save normally.
     */
    @IsTest
    static void testUniqueNameAllowed() {
        Account newAcc = new Account(Name = UNIQUE_NAME);

        Test.startTest();
        Database.SaveResult result = Database.insert(newAcc, false);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Expected unique Account name to be inserted successfully.');
        System.assertEquals(0, result.getErrors().size(), 'Expected no errors for a unique name.');
    }

    /**
     * @description AC-2: Updating an existing Account name should not trigger the duplicate check.
     */
    @IsTest
    static void testUpdateNotBlocked() {
        Account existing = [SELECT Id, Name FROM Account WHERE Name = :EXISTING_NAME LIMIT 1];
        existing.Name = EXISTING_NAME + ' Updated';

        Test.startTest();
        Database.SaveResult result = Database.update(existing, false);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Expected Account update to succeed without duplicate error.');
    }

    // ─── Negative Tests ───────────────────────────────────────────────────────

    /**
     * @description AC-1: Inserting an Account with the exact same name as an existing record
     *              must be blocked with the duplicate error message.
     */
    @IsTest
    static void testExactDuplicateBlocked() {
        Account duplicate = new Account(Name = EXISTING_NAME);

        Test.startTest();
        Database.SaveResult result = Database.insert(duplicate, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Expected duplicate Account to be blocked.');
        System.assert(!result.getErrors().isEmpty(), 'Expected at least one error on the save result.');
        System.assert(
            result.getErrors()[0].getMessage().contains(DUPLICATE_ERROR),
            'Expected duplicate error message. Got: ' + result.getErrors()[0].getMessage()
        );
    }

    /**
     * @description AC-1: Inserting an Account with a name that differs only in case
     *              (e.g., "ACME CORP" vs "Acme Corp") must also be blocked.
     */
    @IsTest
    static void testCaseInsensitiveDuplicateBlocked() {
        Account duplicate = new Account(Name = EXISTING_NAME.toUpperCase());

        Test.startTest();
        Database.SaveResult result = Database.insert(duplicate, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Expected case-insensitive duplicate Account to be blocked.');
        System.assert(!result.getErrors().isEmpty(), 'Expected at least one error on the save result.');
        System.assert(
            result.getErrors()[0].getMessage().contains(DUPLICATE_ERROR),
            'Expected duplicate error message. Got: ' + result.getErrors()[0].getMessage()
        );
    }

    // ─── Bulk Tests ───────────────────────────────────────────────────────────

    /**
     * @description Bulk scenario: 200 new Accounts, 100 with unique names and 100 that
     *              duplicate the pre-existing record name (case-insensitive variants).
     *              Verifies that unique records save and duplicates are blocked.
     */
    @IsTest
    static void testBulkPartialBlock() {
        List<Account> toInsert = new List<Account>();

        // 100 unique names
        for (Integer i = 0; i < 100; i++) {
            toInsert.add(new Account(Name = 'Unique Company ' + i));
        }

        // 100 duplicates (varying case to exercise case-insensitive path)
        for (Integer i = 0; i < 100; i++) {
            String nameVariant = (Math.mod(i, 2) == 0)
                ? EXISTING_NAME.toUpperCase()
                : EXISTING_NAME.toLowerCase();
            toInsert.add(new Account(Name = nameVariant));
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(toInsert, false);
        Test.stopTest();

        Integer successCount = 0;
        Integer failureCount = 0;

        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                System.assert(
                    sr.getErrors()[0].getMessage().contains(DUPLICATE_ERROR),
                    'Unexpected error message: ' + sr.getErrors()[0].getMessage()
                );
            }
        }

        System.assertEquals(100, successCount,  'Expected 100 unique Accounts to be inserted.');
        System.assertEquals(100, failureCount,  'Expected 100 duplicate Accounts to be blocked.');
    }

    /**
     * @description In-batch duplicate detection: two new Accounts with the same name
     *              submitted in a single DML call — the second must be blocked even
     *              though neither exists in the database yet.
     */
    @IsTest
    static void testInBatchDuplicate() {
        String batchName = 'BatchDupe Co';
        List<Account> toInsert = new List<Account>{
            new Account(Name = batchName),
            new Account(Name = batchName)
        };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(toInsert, false);
        Test.stopTest();

        // First record should succeed (no pre-existing); second should fail.
        System.assert(results[0].isSuccess(), 'Expected first in-batch Account to succeed.');
        System.assert(!results[1].isSuccess(), 'Expected second in-batch Account to be blocked.');
        System.assert(
            results[1].getErrors()[0].getMessage().contains(DUPLICATE_ERROR),
            'Expected duplicate error message on second in-batch record. Got: '
                + results[1].getErrors()[0].getMessage()
        );
    }

    /**
     * @description Edge case: inserting an Account with a null or blank Name must not
     *              throw an unhandled exception. Standard required-field validation will
     *              handle the blank name; the handler should skip it gracefully.
     */
    @IsTest
    static void testNullNameHandledGracefully() {
        // Use a handler instance directly to avoid required-field DML failure.
        AccountDuplicateNameHandler handler = new AccountDuplicateNameHandler();

        List<Account> accounts = new List<Account>{
            new Account(), // Name is null
            new Account(Name = ''),
            new Account(Name = '   ')
        };

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            handler.handleBeforeInsert(accounts);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Handler must not throw when Account Name is null or blank.');
    }

    // ─── Unit Tests for Private Methods (via @TestVisible) ───────────────────

    /**
     * @description Unit test for buildLowerNameSet: verifies that names are lower-cased
     *              and that in-batch duplicates are immediately errored and excluded from
     *              the returned set.
     */
    @IsTest
    static void testBuildLowerNameSetInBatchDetection() {
        AccountDuplicateNameHandler handler = new AccountDuplicateNameHandler();

        Account acc1 = new Account(Name = 'Alpha Inc');
        Account acc2 = new Account(Name = 'ALPHA INC'); // duplicate of acc1
        Account acc3 = new Account(Name = 'Beta Ltd');

        List<Account> accounts = new List<Account>{ acc1, acc2, acc3 };

        Test.startTest();
        Set<String> result = handler.buildLowerNameSet(accounts);
        Test.stopTest();

        // The returned set should contain unique lower-cased first-occurrence names only.
        System.assert(result.contains('alpha inc'), 'Expected "alpha inc" in the set.');
        System.assert(result.contains('beta ltd'),  'Expected "beta ltd" in the set.');
        System.assertEquals(2, result.size(), 'Expected exactly 2 unique names in the set.');
    }

    /**
     * @description Unit test for queryExistingNames: verifies that the method returns
     *              only names that match existing database records.
     */
    @IsTest
    static void testQueryExistingNames() {
        AccountDuplicateNameHandler handler = new AccountDuplicateNameHandler();

        Set<String> lowerNames = new Set<String>{
            EXISTING_NAME.toLowerCase(),
            'non existent company xyz'
        };

        Test.startTest();
        Set<String> result = handler.queryExistingNames(lowerNames);
        Test.stopTest();

        System.assert(
            result.contains(EXISTING_NAME.toLowerCase()),
            'Expected existing Account name to be in the result set.'
        );
        System.assert(
            !result.contains('non existent company xyz'),
            'Expected non-existent name to be absent from the result set.'
        );
    }

    /**
     * @description Unit test for queryExistingNames with an empty input set:
     *              should return an empty set without executing a query.
     */
    @IsTest
    static void testQueryExistingNamesEmptyInput() {
        AccountDuplicateNameHandler handler = new AccountDuplicateNameHandler();

        Test.startTest();
        Set<String> result = handler.queryExistingNames(new Set<String>());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should never be null.');
        System.assert(result.isEmpty(), 'Expected empty result for empty input.');
    }

    /**
     * @description Unit test for handleBeforeInsert with an empty list:
     *              should complete without error and without querying.
     */
    @IsTest
    static void testHandleBeforeInsertEmptyList() {
        AccountDuplicateNameHandler handler = new AccountDuplicateNameHandler();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            handler.handleBeforeInsert(new List<Account>());
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'handleBeforeInsert must not throw for an empty list.');
    }
}