public with sharing class ForecastService {

    @AuraEnabled(cacheable=true)
    public static List<Sales_Forecast__c> getCurrentForecast(Id territoryId) {
        Date firstOfMonth = Date.today().toStartOfMonth();
        return [SELECT Id, Name, Territory__c, Territory__r.Name, Forecast_Month__c,
                       Target_Amount__c, Committed_Amount__c, Best_Case_Amount__c,
                       Actual_Amount__c, Forecast_Owner__c, Status__c, Attainment__c
                FROM Sales_Forecast__c
                WHERE Territory__c = :territoryId AND Forecast_Month__c = :firstOfMonth];
    }

    @AuraEnabled
    public static String submitForecast(Id forecastId) {
        Sales_Forecast__c forecast = [SELECT Id, Status__c, Target_Amount__c, Committed_Amount__c FROM Sales_Forecast__c WHERE Id = :forecastId];
        if (forecast.Target_Amount__c == null || forecast.Committed_Amount__c == null) {
            throw new AuraHandledException('Target and Committed amounts are required before submission');
        }
        forecast.Status__c = 'Submitted';
        update forecast;
        return 'Forecast submitted successfully';
    }

    @AuraEnabled
    public static String approveForecast(Id forecastId) {
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        if (p.Name != 'System Administrator') {
            throw new AuraHandledException('Only administrators can approve forecasts');
        }
        Sales_Forecast__c forecast = [SELECT Id, Status__c FROM Sales_Forecast__c WHERE Id = :forecastId];
        if (forecast.Status__c != 'Submitted') {
            throw new AuraHandledException('Only submitted forecasts can be approved');
        }
        forecast.Status__c = 'Approved';
        update forecast;
        return 'Forecast approved successfully';
    }

    public static void rollupActuals(Set<Id> territoryIds) {
        Date firstOfMonth = Date.today().toStartOfMonth();
        Date lastOfMonth = firstOfMonth.addMonths(1).addDays(-1);

        // Get closed won deals for these territories this month
        Map<Id, Decimal> territoryActuals = new Map<Id, Decimal>();
        for (AggregateResult ar : [SELECT Territory__c, SUM(Deal_Value__c) totalValue
                FROM Deal__c
                WHERE Territory__c IN :territoryIds
                AND Deal_Stage__c = 'Closed Won'
                AND Close_Date__c >= :firstOfMonth
                AND Close_Date__c <= :lastOfMonth
                GROUP BY Territory__c]) {
            territoryActuals.put((Id)ar.get('Territory__c'), (Decimal)ar.get('totalValue'));
        }

        // Update forecast records
        List<Sales_Forecast__c> forecastsToUpdate = [SELECT Id, Territory__c, Actual_Amount__c
                FROM Sales_Forecast__c
                WHERE Territory__c IN :territoryIds AND Forecast_Month__c = :firstOfMonth];
        for (Sales_Forecast__c f : forecastsToUpdate) {
            f.Actual_Amount__c = territoryActuals.containsKey(f.Territory__c) ? territoryActuals.get(f.Territory__c) : 0;
        }
        if (!forecastsToUpdate.isEmpty()) update forecastsToUpdate;
    }
}
