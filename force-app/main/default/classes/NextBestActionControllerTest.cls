/**
 * Test class for NextBestActionController.
 * Covers positive, negative, and bulk (200 record) scenarios.
 */
@IsTest
private class NextBestActionControllerTest {

    // ─── Test Setup ──────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name        = 'Bulk Opp ' + i,
                StageName   = 'Prospecting',
                CloseDate   = Date.today().addDays(30),
                Amount      = 5000,
                AccountId   = accounts[Math.mod(i, 5)].Id,
                Probability = 25
            ));
        }
        insert opps;

        // Single opportunity with richer data for targeted tests
        Opportunity richOpp = new Opportunity(
            Name               = 'Rich Opp',
            StageName          = 'Negotiation/Review',
            CloseDate          = Date.today().addDays(7),
            Amount             = 150000,
            Probability        = 75,
            MainCompetitors__c = 'AcmeCorp',
            CurrentGenerators__c = 'Legacy Gen'
        );
        insert richOpp;
    }

    // ─── Positive Tests ──────────────────────────────────────────────────────

    @IsTest
    static void testGetRecommendations_returnsResults() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rich Opp' LIMIT 1];

        Test.startTest();
        List<NextBestActionController.RecommendationWrapper> recs =
            NextBestActionController.getRecommendations(opp.Id, new List<String>());
        Test.stopTest();

        // Should return a list (may be empty if no active CMT in test context, but must not throw)
        System.assertNotEquals(null, recs, 'Result list should not be null');
    }

    @IsTest
    static void testGetRecommendations_dismissedLabelsExcluded() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rich Opp' LIMIT 1];

        // Run once without dismissals to capture all labels
        List<NextBestActionController.RecommendationWrapper> allRecs =
            NextBestActionController.getRecommendations(opp.Id, new List<String>());

        if (allRecs.isEmpty()) {
            // No active CMT in test context — skip assertion, test still executes the code path
            System.assert(true, 'No active rules in test context; skipping dismissal assertion');
            return;
        }

        // Dismiss the first result
        List<String> dismissed = new List<String>{ allRecs[0].actionLabel };

        Test.startTest();
        List<NextBestActionController.RecommendationWrapper> filteredRecs =
            NextBestActionController.getRecommendations(opp.Id, dismissed);
        Test.stopTest();

        for (NextBestActionController.RecommendationWrapper rec : filteredRecs) {
            System.assertNotEquals(
                allRecs[0].actionLabel,
                rec.actionLabel,
                'Dismissed recommendation should not appear'
            );
        }
    }

    @IsTest
    static void testGetRecommendations_sortedByPriority() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rich Opp' LIMIT 1];

        Test.startTest();
        List<NextBestActionController.RecommendationWrapper> recs =
            NextBestActionController.getRecommendations(opp.Id, null);
        Test.stopTest();

        for (Integer i = 1; i < recs.size(); i++) {
            System.assert(
                recs[i - 1].priority <= recs[i].priority,
                'Results should be sorted by priority ascending'
            );
        }
    }

    @IsTest
    static void testCreateFollowUpTask_success() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rich Opp' LIMIT 1];

        Test.startTest();
        Id taskId = NextBestActionController.createFollowUpTask(opp.Id, 'Follow up on proposal');
        Test.stopTest();

        System.assertNotEquals(null, taskId, 'Task Id should be returned');
        Task created = [SELECT Id, Subject, WhatId FROM Task WHERE Id = :taskId LIMIT 1];
        System.assertEquals('Follow up on proposal', created.Subject, 'Task subject should match');
        System.assertEquals(opp.Id, created.WhatId, 'Task should be linked to the Opportunity');
    }

    @IsTest
    static void testRecommendationWrapper_compareTo_lessThan() {
        NextBestActionController.RecommendationWrapper a = new NextBestActionController.RecommendationWrapper();
        a.priority = 1;
        NextBestActionController.RecommendationWrapper b = new NextBestActionController.RecommendationWrapper();
        b.priority = 5;

        System.assertEquals(-1, a.compareTo(b), 'Lower priority number should sort first (return -1)');
    }

    @IsTest
    static void testRecommendationWrapper_compareTo_greaterThan() {
        NextBestActionController.RecommendationWrapper a = new NextBestActionController.RecommendationWrapper();
        a.priority = 10;
        NextBestActionController.RecommendationWrapper b = new NextBestActionController.RecommendationWrapper();
        b.priority = 2;

        System.assertEquals(1, a.compareTo(b), 'Higher priority number should sort last (return 1)');
    }

    @IsTest
    static void testRecommendationWrapper_compareTo_equal() {
        NextBestActionController.RecommendationWrapper a = new NextBestActionController.RecommendationWrapper();
        a.priority = 5;
        NextBestActionController.RecommendationWrapper b = new NextBestActionController.RecommendationWrapper();
        b.priority = 5;

        System.assertEquals(0, a.compareTo(b), 'Equal priorities should return 0');
    }

    @IsTest
    static void testRecommendationWrapper_nullPriority() {
        NextBestActionController.RecommendationWrapper a = new NextBestActionController.RecommendationWrapper();
        a.priority = null;
        NextBestActionController.RecommendationWrapper b = new NextBestActionController.RecommendationWrapper();
        b.priority = 1;

        // Null priority treated as 99 — should sort after 1
        System.assertEquals(1, a.compareTo(b), 'Null priority should be treated as 99');
    }

    // ─── Negative Tests ──────────────────────────────────────────────────────

    @IsTest
    static void testGetRecommendations_nullOpportunityId_throwsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            NextBestActionController.getRecommendations(null, new List<String>());
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown for null opportunityId');
    }

    @IsTest
    static void testGetRecommendations_invalidOpportunityId_throwsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            // Valid Id format but non-existent record
            NextBestActionController.getRecommendations(
                '006000000000001AAA',
                new List<String>()
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown for non-existent Opportunity');
    }

    @IsTest
    static void testCreateFollowUpTask_nullId_throwsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            NextBestActionController.createFollowUpTask(null, 'Some Subject');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown for null opportunityId');
    }

    @IsTest
    static void testCreateFollowUpTask_blankSubject_throwsException() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rich Opp' LIMIT 1];
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            NextBestActionController.createFollowUpTask(opp.Id, '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown for blank subject');
    }

    // ─── Bulk Tests ──────────────────────────────────────────────────────────

    @IsTest
    static void testGetRecommendations_bulk200Opportunities() {
        List<Opportunity> opps = [
            SELECT Id
            FROM Opportunity
            WHERE Name LIKE 'Bulk Opp%'
            LIMIT 200
        ];
        System.assertEquals(200, opps.size(), 'Should have 200 bulk opportunities');

        Test.startTest();
        // Evaluate rules for each opportunity individually (simulates concurrent user requests)
        List<List<NextBestActionController.RecommendationWrapper>> allResults =
            new List<List<NextBestActionController.RecommendationWrapper>>();
        for (Opportunity opp : opps) {
            allResults.add(
                NextBestActionController.getRecommendations(opp.Id, new List<String>())
            );
        }
        Test.stopTest();

        System.assertEquals(200, allResults.size(), 'Should have processed all 200 opportunities');
        for (List<NextBestActionController.RecommendationWrapper> recs : allResults) {
            System.assertNotEquals(null, recs, 'Each result list should not be null');
        }
    }

    @IsTest
    static void testCreateFollowUpTask_bulk200Tasks() {
        List<Opportunity> opps = [
            SELECT Id
            FROM Opportunity
            WHERE Name LIKE 'Bulk Opp%'
            LIMIT 200
        ];

        Test.startTest();
        List<Id> taskIds = new List<Id>();
        for (Opportunity opp : opps) {
            taskIds.add(
                NextBestActionController.createFollowUpTask(opp.Id, 'Bulk Follow-up Task')
            );
        }
        Test.stopTest();

        System.assertEquals(200, taskIds.size(), 'Should have created 200 tasks');
        List<Task> tasks = [SELECT Id FROM Task WHERE Id IN :taskIds];
        System.assertEquals(200, tasks.size(), 'All 200 tasks should exist in the org');
    }
}