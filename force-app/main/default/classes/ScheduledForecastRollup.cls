public class ScheduledForecastRollup implements Schedulable {

    public void execute(SchedulableContext sc) {
        Set<Id> allTerritoryIds = new Set<Id>();
        for (Sales_Territory__c t : [SELECT Id FROM Sales_Territory__c WHERE Active__c = true]) {
            allTerritoryIds.add(t.Id);
        }
        if (!allTerritoryIds.isEmpty()) {
            ForecastService.rollupActuals(allTerritoryIds);
        }
    }

    public static String scheduleMonthly() {
        return System.schedule('Monthly Forecast Rollup', '0 0 1 1 * ?', new ScheduledForecastRollup());
    }
}
