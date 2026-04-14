public class BatchUpdateDealHealth implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date sevenDaysAgo = Date.today().addDays(-7);
        return Database.getQueryLocator([
            SELECT Id, Deal_Stage__c, Win_Probability__c, LastModifiedDate
            FROM Deal__c
            WHERE Deal_Stage__c NOT IN ('Closed Won', 'Closed Lost')
            AND LastModifiedDate < :sevenDaysAgo
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Deal__c> scope) {
        for (Deal__c deal : scope) {
            // Reduce probability for stale deals
            if (deal.Win_Probability__c != null && deal.Win_Probability__c > 10) {
                deal.Win_Probability__c = deal.Win_Probability__c - 5;
            }
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('BatchUpdateDealHealth completed');
    }
}
