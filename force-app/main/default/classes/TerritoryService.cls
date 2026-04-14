public with sharing class TerritoryService {

    public class TerritorySummary {
        @AuraEnabled public Integer totalDeals;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public Decimal attainmentPercentage;
    }

    @AuraEnabled(cacheable=true)
    public static TerritorySummary getTerritorySummary(Id territoryId) {
        // Query deals where Territory__c = territoryId
        // Calculate totalDeals, totalValue
        // Query Sales_Territory__c for Annual_Target__c, calculate attainment
        TerritorySummary summary = new TerritorySummary();
        List<Deal__c> deals = [SELECT Id, Deal_Value__c FROM Deal__c WHERE Territory__c = :territoryId AND Deal_Stage__c = 'Closed Won'];
        summary.totalDeals = deals.size();
        summary.totalValue = 0;
        for (Deal__c d : deals) {
            if (d.Deal_Value__c != null) summary.totalValue += d.Deal_Value__c;
        }
        Sales_Territory__c territory = [SELECT Annual_Target__c FROM Sales_Territory__c WHERE Id = :territoryId];
        summary.attainmentPercentage = territory.Annual_Target__c != null && territory.Annual_Target__c > 0
            ? (summary.totalValue / territory.Annual_Target__c) * 100 : 0;
        return summary;
    }

    @AuraEnabled
    public static void assignDealToTerritory(Id dealId, Id territoryId) {
        Deal__c deal = [SELECT Id FROM Deal__c WHERE Id = :dealId];
        deal.Territory__c = territoryId;
        update deal;
    }

    @AuraEnabled(cacheable=true)
    public static List<Sales_Territory__c> getTopPerformers(Integer limitCount) {
        return [SELECT Id, Name, Territory_Manager__c, Annual_Target__c, Quota_Attainment__c, Region__c
                FROM Sales_Territory__c
                WHERE Active__c = true
                ORDER BY Quota_Attainment__c DESC NULLS LAST
                LIMIT :limitCount];
    }

    public static Sales_Forecast__c getForecastForTerritory(Id territoryId, Date forecastMonth) {
        List<Sales_Forecast__c> forecasts = [SELECT Id, Target_Amount__c, Committed_Amount__c, Best_Case_Amount__c, Actual_Amount__c, Status__c
                FROM Sales_Forecast__c
                WHERE Territory__c = :territoryId AND Forecast_Month__c = :forecastMonth
                LIMIT 1];
        return forecasts.isEmpty() ? null : forecasts[0];
    }
}
