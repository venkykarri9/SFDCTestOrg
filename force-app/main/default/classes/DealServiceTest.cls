@isTest
private class DealServiceTest {

    @TestSetup
    static void makeData() {
        Sales_Territory__c territory = new Sales_Territory__c(
            Name = 'Test Territory',
            Region__c = 'East',
            Annual_Target__c = 1000000,
            Active__c = true,
            Country_Code__c = 'US'
        );
        insert territory;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id);
        insert con;

        List<Deal__c> deals = new List<Deal__c>{
            new Deal__c(Account__c = acc.Id, Primary_Contact__c = con.Id, Deal_Stage__c = 'Proposal',
                       Deal_Value__c = 100000, Win_Probability__c = 50, Close_Date__c = Date.today().addDays(30),
                       Territory__c = territory.Id),
            new Deal__c(Account__c = acc.Id, Deal_Stage__c = 'Closed Won', Deal_Value__c = 200000,
                       Win_Probability__c = 100, Close_Date__c = Date.today().addDays(-5),
                       Territory__c = territory.Id),
            new Deal__c(Account__c = acc.Id, Deal_Stage__c = 'Closed Lost', Deal_Value__c = 50000,
                       Win_Probability__c = 0, Close_Date__c = Date.today().addDays(-3),
                       Next_Step__c = 'Lost to competitor', Territory__c = territory.Id)
        };
        insert deals;
    }

    @isTest
    static void testGetRecentDeals() {
        Test.startTest();
        List<Deal__c> deals = DealService.getRecentDeals(10);
        Test.stopTest();
        System.assert(deals.size() > 0, 'Should return deals');
    }

    @isTest
    static void testUpdateDealStage() {
        Deal__c deal = [SELECT Id FROM Deal__c WHERE Deal_Stage__c = 'Proposal' LIMIT 1];
        Test.startTest();
        String result = DealService.updateDealStage(deal.Id, 'Negotiation');
        Test.stopTest();
        System.assertEquals('Success', result);
    }

    @isTest
    static void testGetWinLossAnalysis() {
        Test.startTest();
        Map<String, Object> analysis = DealService.getWinLossAnalysis(12);
        Test.stopTest();
        System.assertNotEquals(null, analysis);
    }

    @isTest
    static void testGetDealsByTerritory() {
        Sales_Territory__c territory = [SELECT Id FROM Sales_Territory__c LIMIT 1];
        Test.startTest();
        List<Deal__c> deals = DealService.getDealsByTerritory(territory.Id);
        Test.stopTest();
        System.assert(deals.size() > 0, 'Should return deals for territory');
    }

    @isTest
    static void testCloneDeal() {
        Deal__c deal = [SELECT Id FROM Deal__c WHERE Deal_Stage__c = 'Proposal' LIMIT 1];
        Test.startTest();
        Id clonedId = DealCloneService.cloneDeal(deal.Id);
        Test.stopTest();
        System.assertNotEquals(null, clonedId);
        Deal__c cloned = [SELECT Deal_Stage__c FROM Deal__c WHERE Id = :clonedId];
        System.assertEquals('Prospecting', cloned.Deal_Stage__c);
    }

    @isTest
    static void testMergeDuplicateDeals() {
        List<Deal__c> deals = [SELECT Id FROM Deal__c WHERE Deal_Stage__c != 'Closed Lost' LIMIT 2];
        System.assert(deals.size() >= 2, 'Need at least 2 deals');
        Test.startTest();
        String result = DealCloneService.mergeDuplicateDeals(deals[0].Id, deals[1].Id);
        Test.stopTest();
        System.assertEquals('Deals merged successfully', result);
    }
}
