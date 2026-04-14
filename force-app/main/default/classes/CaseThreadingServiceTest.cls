/**
 * @description Test class for CaseThreadingService and CaseTrigger.
 * Covers: single match, non-existent reference, no reference in subject,
 * malformed reference, bulk 200 records, thread depth field, preset ParentId
 * preservation, and multiple [Ref:] tokens (first match wins).
 *
 * Minimum coverage target: 85%.
 */
@IsTest
private with sharing class CaseThreadingServiceTest {

    // ─── Test Setup ───────────────────────────────────────────────────────────

    /**
     * @description Creates a reusable parent Case whose CaseNumber is assigned
     * by the platform after insert. Retrieved in each test via SOQL.
     */
    @TestSetup
    static void makeData() {
        // Insert a parent Case. CaseNumber is auto-assigned by the platform.
        Case parent = new Case(
            Subject = 'Parent Case for Threading Tests',
            Status  = 'New',
            Origin  = 'Email'
        );
        insert parent;
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    /**
     * @description Retrieves the parent Case created in @TestSetup.
     * @return The parent Case record with Id and CaseNumber populated.
     */
    private static Case getParentCase() {
        return [SELECT Id, CaseNumber FROM Case WHERE Subject = 'Parent Case for Threading Tests' LIMIT 1];
    }

    // ─── AC-1 / Positive: Single match threads correctly ──────────────────────

    /**
     * @description Verifies that a new Case whose Subject contains a valid
     * [Ref:XXXXXXXX] token is linked to the parent Case and Is_Threaded__c = true.
     */
    @IsTest
    static void testSingleMatch() {
        Case parent = getParentCase();

        Case child = new Case(
            Subject = 'Re: Your ticket [Ref:' + parent.CaseNumber + '] follow-up',
            Status  = 'New',
            Origin  = 'Email'
        );
        Test.startTest();
        insert child;
        Test.stopTest();

        Case result = [SELECT Id, ParentId, Is_Threaded__c FROM Case WHERE Id = :child.Id];
        System.assertEquals(parent.Id, result.ParentId,
            'ParentId should be set to the referenced parent Case.');
        System.assertEquals(true, result.Is_Threaded__c,
            'Is_Threaded__c should be true when threading succeeds.');
    }

    // ─── AC-4 / Negative: Non-existent reference skips silently ──────────────

    /**
     * @description Verifies that a [Ref:] token referencing a non-existent
     * CaseNumber results in no ParentId assignment and no error.
     */
    @IsTest
    static void testNoMatchNonExistentRef() {
        Case child = new Case(
            Subject = 'Query about [Ref:99999999]',
            Status  = 'New',
            Origin  = 'Email'
        );
        Test.startTest();
        insert child;
        Test.stopTest();

        Case result = [SELECT Id, ParentId, Is_Threaded__c FROM Case WHERE Id = :child.Id];
        System.assertEquals(null, result.ParentId,
            'ParentId should remain null when the referenced Case does not exist.');
        System.assertEquals(false, result.Is_Threaded__c,
            'Is_Threaded__c should be false when no threading occurs.');
    }

    // ─── Negative: No [Ref:] token in Subject ─────────────────────────────────

    /**
     * @description Verifies that a Case with no [Ref:] token in its Subject
     * is inserted normally without any ParentId assignment.
     */
    @IsTest
    static void testNoRefInSubject() {
        Test.startTest();
        Case child = new Case(
            Subject = 'Brand new issue with no reference',
            Status  = 'New',
            Origin  = 'Web'
        );
        insert child;
        Test.stopTest();

        Case result = [SELECT Id, ParentId, Is_Threaded__c FROM Case WHERE Id = :child.Id];
        System.assertEquals(null, result.ParentId,
            'ParentId should remain null when no [Ref:] token is present.');
        System.assertEquals(false, result.Is_Threaded__c,
            'Is_Threaded__c should be false when no threading occurs.');
    }

    // ─── Negative: Malformed [Ref:] token does not match ─────────────────────

    /**
     * @description Verifies that malformed [Ref:] tokens (wrong digit count,
     * non-numeric characters, missing brackets) do not trigger threading.
     */
    @IsTest
    static void testMalformedRef() {
        Test.startTest();
        List<Case> malformedCases = new List<Case>{
            // Fewer than 8 digits
            new Case(Subject = 'Issue [Ref:1234]', Status = 'New', Origin = 'Email'),
            // More than 8 digits
            new Case(Subject = 'Issue [Ref:123456789]', Status = 'New', Origin = 'Email'),
            // Non-numeric characters
            new Case(Subject = 'Issue [Ref:ABCD1234]', Status = 'New', Origin = 'Email'),
            // Missing closing bracket
            new Case(Subject = 'Issue [Ref:12345678', Status = 'New', Origin = 'Email'),
            // Missing opening bracket
            new Case(Subject = 'Issue Ref:12345678]', Status = 'New', Origin = 'Email')
        };
        insert malformedCases;
        Test.stopTest();

        List<Case> results = [
            SELECT Id, ParentId, Is_Threaded__c
            FROM Case
            WHERE Id IN :malformedCases
        ];
        for (Case c : results) {
            System.assertEquals(false, c.Is_Threaded__c,
                'Is_Threaded__c should be false for malformed tokens.');
        }
    }

    // ─── AC-6 / Bulk: 200 Cases threaded in one transaction ───────────────────

    /**
     * @description Verifies that 200 Cases containing valid [Ref:] tokens
     * are all correctly threaded in a single trigger invocation using one SOQL.
     */
    @IsTest
    static void testBulk200Cases() {
        Case parent = getParentCase();

        List<Case> children = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            children.add(new Case(
                Subject = 'Bulk email [Ref:' + parent.CaseNumber + '] item ' + i,
                Status  = 'New',
                Origin  = 'Email'
            ));
        }

        Test.startTest();
        insert children;
        Test.stopTest();

        List<Case> results = [
            SELECT Id, ParentId, Is_Threaded__c
            FROM Case
            WHERE Id IN :children
        ];
        System.assertEquals(200, results.size(), 'All 200 Cases should be inserted.');
        for (Case c : results) {
            System.assertEquals(parent.Id, c.ParentId,
                'Every bulk Case should be threaded to the parent.');
            System.assertEquals(true, c.Is_Threaded__c,
                'Is_Threaded__c should be true for all threaded bulk Cases.');
        }
    }

    // ─── AC-3 / Thread depth formula field is present and readable ────────────

    /**
     * @description Verifies that Thread_Depth__c is accessible on the Case object
     * and returns a numeric value. Also confirms a two-level hierarchy has depth >= 1.
     */
    @IsTest
    static void testThreadDepth() {
        Case parent = getParentCase();

        Test.startTest();
        Case child = new Case(
            Subject = 'Child case [Ref:' + parent.CaseNumber + ']',
            Status  = 'New',
            Origin  = 'Email'
        );
        insert child;
        Test.stopTest();

        // Thread_Depth__c is a formula — query it after insert.
        Case result = [
            SELECT Id, ParentId, Thread_Depth__c
            FROM Case
            WHERE Id = :child.Id
        ];
        System.assertEquals(parent.Id, result.ParentId,
            'Child should be linked to parent for depth test.');
        System.assertNotEquals(null, result.Thread_Depth__c,
            'Thread_Depth__c formula field should return a non-null value.');
        System.assert(result.Thread_Depth__c >= 1,
            'A child Case with a parent should have Thread_Depth__c >= 1.');
    }

    // ─── AC-2 / Preset ParentId is NOT overwritten ────────────────────────────

    /**
     * @description Verifies that if a Case already has ParentId set before the
     * trigger fires (e.g. programmatically set), the service does not overwrite it,
     * even when a valid [Ref:] token is present in the Subject.
     */
    @IsTest
    static void testPresetParentIdNotOverwritten() {
        Case parent = getParentCase();

        // Create a second Case to act as the "pre-set" parent.
        Case presetParent = new Case(
            Subject = 'Pre-set parent case',
            Status  = 'New',
            Origin  = 'Phone'
        );
        insert presetParent;

        Test.startTest();
        // The child has a [Ref:] pointing to parent, but ParentId is already set to presetParent.
        Case child = new Case(
            Subject  = 'Issue [Ref:' + parent.CaseNumber + '] with preset parent',
            Status   = 'New',
            Origin   = 'Email',
            ParentId = presetParent.Id
        );
        insert child;
        Test.stopTest();

        Case result = [SELECT Id, ParentId FROM Case WHERE Id = :child.Id];
        System.assertEquals(presetParent.Id, result.ParentId,
            'Pre-set ParentId must NOT be overwritten by the threading service.');
    }

    // ─── Multiple [Ref:] tokens — first match wins ────────────────────────────

    /**
     * @description Verifies that when a Subject contains multiple [Ref:] tokens,
     * only the first token is used for threading.
     */
    @IsTest
    static void testMultipleRefsFirstMatchWins() {
        Case parent = getParentCase();

        Test.startTest();
        // Second token references a non-existent Case to confirm first-match behaviour.
        Case child = new Case(
            Subject = 'Re: [Ref:' + parent.CaseNumber + '] and also [Ref:99999999]',
            Status  = 'New',
            Origin  = 'Email'
        );
        insert child;
        Test.stopTest();

        Case result = [SELECT Id, ParentId, Is_Threaded__c FROM Case WHERE Id = :child.Id];
        System.assertEquals(parent.Id, result.ParentId,
            'The first [Ref:] token should win and ParentId should be the real parent.');
        System.assertEquals(true, result.Is_Threaded__c,
            'Is_Threaded__c should be true when the first token resolves successfully.');
    }

    // ─── Unit: extractRefNumbers ──────────────────────────────────────────────

    /**
     * @description Unit-tests the public extractRefNumbers utility method directly.
     */
    @IsTest
    static void testExtractRefNumbers() {
        List<Case> cases = new List<Case>{
            new Case(Subject = 'Hello [Ref:00001234] world'),
            new Case(Subject = 'No ref here'),
            new Case(Subject = null),
            new Case(Subject = '[Ref:00005678] and [Ref:00009999]')
        };

        Test.startTest();
        Set<String> refs = CaseThreadingService.extractRefNumbers(cases);
        Test.stopTest();

        System.assertEquals(2, refs.size(),
            'Should extract exactly 2 unique reference numbers.');
        System.assert(refs.contains('00001234'), 'Should contain 00001234.');
        System.assert(refs.contains('00005678'), 'Should contain 00005678 (first token of last subject).');
    }

    // ─── Unit: resolveParentIds with empty set ────────────────────────────────

    /**
     * @description Verifies that resolveParentIds returns an empty map when
     * called with an empty or null set (guard clause coverage).
     */
    @IsTest
    static void testResolveParentIdsEmptyInput() {
        Test.startTest();
        Map<String, Id> resultEmpty = CaseThreadingService.resolveParentIds(new Set<String>());
        Map<String, Id> resultNull  = CaseThreadingService.resolveParentIds(null);
        Test.stopTest();

        System.assert(resultEmpty.isEmpty(),
            'resolveParentIds with empty set should return empty map.');
        System.assert(resultNull.isEmpty(),
            'resolveParentIds with null should return empty map.');
    }

    // ─── Guard: null / empty list passed to threadCases ──────────────────────

    /**
     * @description Verifies that threadCases handles null and empty list inputs
     * without throwing an exception.
     */
    @IsTest
    static void testThreadCasesGuardClauses() {
        Test.startTest();
        // Should not throw
        CaseThreadingService.threadCases(null);
        CaseThreadingService.threadCases(new List<Case>());
        Test.stopTest();
        // If we reach here, no exception was thrown — test passes.
        System.assert(true, 'threadCases should handle null and empty lists gracefully.');
    }
}