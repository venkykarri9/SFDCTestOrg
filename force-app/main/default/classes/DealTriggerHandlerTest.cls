@isTest
private class DealTriggerHandlerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;
    }

    @isTest
    static void testInsertDeal_setsDefaults() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Deal__c deal = new Deal__c(
            Account__c = acc.Id,
            Close_Date__c = Date.today().addDays(30)
        );

        Test.startTest();
        insert deal;
        Test.stopTest();

        Deal__c inserted = [SELECT Id, Win_Probability__c, Deal_Stage__c FROM Deal__c WHERE Id = :deal.Id];
        System.assertEquals(10, inserted.Win_Probability__c, 'Default probability should be 10');
        System.assertEquals('Prospecting', inserted.Deal_Stage__c, 'Default stage should be Prospecting');
    }

    @isTest
    static void testInsertDeal_pastCloseDateFails() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Deal__c deal = new Deal__c(
            Account__c = acc.Id,
            Close_Date__c = Date.today().addDays(-1)
        );

        Test.startTest();
        try {
            insert deal;
            System.assert(false, 'Should have thrown exception');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Close Date cannot be in the past'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateStage_updatesProbability() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Deal__c deal = new Deal__c(
            Account__c = acc.Id,
            Close_Date__c = Date.today().addDays(30)
        );
        insert deal;

        Test.startTest();
        deal.Deal_Stage__c = 'Proposal';
        update deal;
        Test.stopTest();

        Deal__c updated = [SELECT Win_Probability__c FROM Deal__c WHERE Id = :deal.Id];
        System.assertEquals(50, updated.Win_Probability__c, 'Proposal stage should set 50% probability');
    }

    @isTest
    static void testClosedWonCannotRevert() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Deal__c deal = new Deal__c(
            Account__c = acc.Id,
            Close_Date__c = Date.today().addDays(30),
            Deal_Stage__c = 'Closed Won',
            Win_Probability__c = 100
        );
        insert deal;

        Test.startTest();
        try {
            deal.Deal_Stage__c = 'Negotiation';
            update deal;
            System.assert(false, 'Should have thrown exception');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Cannot change stage from Closed Won'));
        }
        Test.stopTest();
    }

    @isTest
    static void testInsertDeal_requiresAccount() {
        Deal__c deal = new Deal__c(
            Close_Date__c = Date.today().addDays(30)
        );

        Test.startTest();
        try {
            insert deal;
            System.assert(false, 'Should have thrown exception');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Account is required'), 'Error should mention Account is required');
        }
        Test.stopTest();
    }

    @isTest
    static void testAfterInsert_createsWelcomeActivity() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Deal__c deal = new Deal__c(
            Account__c = acc.Id,
            Close_Date__c = Date.today().addDays(30)
        );

        Test.startTest();
        insert deal;
        Test.stopTest();

        List<Deal_Activity__c> activities = [SELECT Id, Activity_Type__c, Notes__c FROM Deal_Activity__c WHERE Deal__c = :deal.Id];
        System.assertEquals(1, activities.size(), 'Should create one welcome activity');
        System.assertEquals('Call', activities[0].Activity_Type__c, 'Activity type should be Call');
    }

    @isTest
    static void testBulkInsert_200Deals() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<Deal__c> deals = new List<Deal__c>();
        for (Integer i = 0; i < 200; i++) {
            deals.add(new Deal__c(
                Account__c = acc.Id,
                Close_Date__c = Date.today().addDays(30)
            ));
        }

        Test.startTest();
        insert deals;
        Test.stopTest();

        List<Deal__c> inserted = [SELECT Id, Win_Probability__c FROM Deal__c WHERE Id IN :deals];
        System.assertEquals(200, inserted.size(), 'All 200 deals should be inserted');
        for (Deal__c d : inserted) {
            System.assertEquals(10, d.Win_Probability__c, 'Each deal should have default probability of 10');
        }
    }
}
