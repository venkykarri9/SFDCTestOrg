/**
 * @description Test class for OpportunityTriggerHandler.
 * Covers:
 *   - Positive: CloseDate pushed forward > 14 days  → event published
 *   - Negative: CloseDate pulled back               → no event
 *   - Negative: CloseDate pushed exactly 14 days    → no event (threshold is exclusive)
 *   - Negative: CloseDate unchanged                 → no event
 *   - Bulk:     200 records, mixed qualifying/non-qualifying
 */
@isTest
private class OpportunityTriggerHandlerTest {

    // ─── Constants ────────────────────────────────────────────────────────────

    private static final Date BASE_DATE   = Date.newInstance(2025, 6, 1);
    private static final Date PUSHED_15   = BASE_DATE.addDays(15);  // qualifies
    private static final Date PUSHED_14   = BASE_DATE.addDays(14);  // does NOT qualify (not > 14)
    private static final Date PULLED_BACK = BASE_DATE.addDays(-5);  // does NOT qualify

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // Single account shared by all test methods
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    /**
     * @description Creates and inserts a set of Opportunities with CloseDate = BASE_DATE.
     */
    private static List<Opportunity> createOpportunities(Integer count) {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < count; i++) {
            opps.add(new Opportunity(
                Name        = 'Test Opp ' + i,
                AccountId   = acc.Id,
                StageName   = 'Prospecting',
                CloseDate   = BASE_DATE
            ));
        }
        insert opps;
        return opps;
    }

    // ─── Positive: push > 14 days ─────────────────────────────────────────────

    @isTest
    static void testCloseDatePushedOver14Days_publishesEvent() {
        List<Opportunity> opps = createOpportunities(1);
        Opportunity opp = opps[0];

        // Simulate the old state manually via buildEvents to verify payload
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(Id = opp.Id, CloseDate = BASE_DATE)
        };
        opp.CloseDate = PUSHED_15;

        Test.startTest();
        List<Close_Date_Pushed__e> events =
            OpportunityTriggerHandler.buildEvents(new List<Opportunity>{ opp }, oldMap);
        Test.stopTest();

        Assert.areEqual(1, events.size(),
            'Expected exactly one event for a 15-day push');

        Close_Date_Pushed__e evt = events[0];
        Assert.areEqual(opp.Id,   evt.Opportunity_Id__c, 'OppId mismatch');
        Assert.areEqual(BASE_DATE, evt.Old_Close_Date__c, 'OldDate mismatch');
        Assert.areEqual(PUSHED_15, evt.New_Close_Date__c, 'NewDate mismatch');
        Assert.areEqual(15,        (Integer) evt.Days_Pushed__c, 'DaysPushed mismatch');
    }

    // ─── Negative: exactly 14 days (boundary — NOT > 14) ─────────────────────

    @isTest
    static void testCloseDatePushedExactly14Days_noEvent() {
        List<Opportunity> opps = createOpportunities(1);
        Opportunity opp = opps[0];

        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(Id = opp.Id, CloseDate = BASE_DATE)
        };
        opp.CloseDate = PUSHED_14;

        Test.startTest();
        List<Close_Date_Pushed__e> events =
            OpportunityTriggerHandler.buildEvents(new List<Opportunity>{ opp }, oldMap);
        Test.stopTest();

        Assert.areEqual(0, events.size(),
            'Expected no event for exactly 14-day push (threshold is exclusive)');
    }

    // ─── Negative: CloseDate pulled back ──────────────────────────────────────

    @isTest
    static void testCloseDatePulledBack_noEvent() {
        List<Opportunity> opps = createOpportunities(1);
        Opportunity opp = opps[0];

        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(Id = opp.Id, CloseDate = BASE_DATE)
        };
        opp.CloseDate = PULLED_BACK;

        Test.startTest();
        List<Close_Date_Pushed__e> events =
            OpportunityTriggerHandler.buildEvents(new List<Opportunity>{ opp }, oldMap);
        Test.stopTest();

        Assert.areEqual(0, events.size(),
            'Expected no event when CloseDate is moved backward');
    }

    // ─── Negative: CloseDate unchanged ────────────────────────────────────────

    @isTest
    static void testCloseDateUnchanged_noEvent() {
        List<Opportunity> opps = createOpportunities(1);
        Opportunity opp = opps[0];

        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(Id = opp.Id, CloseDate = BASE_DATE)
        };
        // CloseDate remains BASE_DATE

        Test.startTest();
        List<Close_Date_Pushed__e> events =
            OpportunityTriggerHandler.buildEvents(new List<Opportunity>{ opp }, oldMap);
        Test.stopTest();

        Assert.areEqual(0, events.size(),
            'Expected no event when CloseDate is unchanged');
    }

    // ─── Negative: null dates guard ───────────────────────────────────────────

    @isTest
    static void testNullCloseDate_noEvent() {
        List<Opportunity> opps = createOpportunities(1);
        Opportunity opp = opps[0];

        // New date is null — should be skipped gracefully
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(Id = opp.Id, CloseDate = BASE_DATE)
        };
        opp.CloseDate = null;

        Test.startTest();
        List<Close_Date_Pushed__e> events =
            OpportunityTriggerHandler.buildEvents(new List<Opportunity>{ opp }, oldMap);
        Test.stopTest();

        Assert.areEqual(0, events.size(),
            'Expected no event when new CloseDate is null');
    }

    // ─── Bulk: 200 records, half qualifying ───────────────────────────────────

    @isTest
    static void testBulk200Records_halfQualify() {
        List<Opportunity> opps = createOpportunities(200);

        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        for (Opportunity opp : opps) {
            oldMap.put(opp.Id, new Opportunity(Id = opp.Id, CloseDate = BASE_DATE));
        }

        // First 100 pushed 15 days → qualify; last 100 pushed 5 days → do not qualify
        for (Integer i = 0; i < 200; i++) {
            opps[i].CloseDate = (i < 100) ? BASE_DATE.addDays(15) : BASE_DATE.addDays(5);
        }

        Test.startTest();
        List<Close_Date_Pushed__e> events =
            OpportunityTriggerHandler.buildEvents(opps, oldMap);
        Test.stopTest();

        Assert.areEqual(100, events.size(),
            'Expected exactly 100 events for the 100 records pushed > 14 days');

        for (Close_Date_Pushed__e evt : events) {
            Assert.areEqual(BASE_DATE,            evt.Old_Close_Date__c, 'OldDate mismatch in bulk');
            Assert.areEqual(BASE_DATE.addDays(15), evt.New_Close_Date__c, 'NewDate mismatch in bulk');
            Assert.areEqual(15, (Integer) evt.Days_Pushed__c,             'DaysPushed mismatch in bulk');
        }
    }

    // ─── Integration: trigger fires via DML, verifying no exception ───────────

    @isTest
    static void testTriggerFires_viaDirectDml_noException() {
        List<Opportunity> opps = createOpportunities(5);

        // Push all 5 forward by 20 days through actual DML so the trigger executes
        for (Opportunity opp : opps) {
            opp.CloseDate = BASE_DATE.addDays(20);
        }

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            update opps;
        } catch (Exception ex) {
            exceptionThrown = true;
            System.debug(LoggingLevel.ERROR, 'Unexpected exception: ' + ex.getMessage());
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown,
            'No exception expected when trigger publishes platform events');
    }
}