public with sharing class DealNotificationService {

    public static void sendDealClosedWonNotification(List<Deal__c> deals) {
        for (Deal__c deal : deals) {
            // In production, would use CustomNotificationType
            // For now, create a task as notification
            System.debug('Deal Closed Won notification for: ' + deal.Id);
        }
    }

    public static void sendForecastAlertNotification(Id territoryId, Decimal attainment) {
        if (attainment < 50) {
            System.debug('Forecast alert: Territory ' + territoryId + ' at ' + attainment + '% attainment');
        }
    }

    @AuraEnabled
    public static List<Deal__c> getStaleDeals() {
        Date thirtyDaysAgo = Date.today().addDays(-30);
        return [SELECT Id, Name, Deal_Stage__c, Deal_Value__c, Account__c, Account__r.Name, LastModifiedDate
                FROM Deal__c
                WHERE Deal_Stage__c NOT IN ('Closed Won', 'Closed Lost')
                AND LastModifiedDate < :thirtyDaysAgo
                ORDER BY LastModifiedDate ASC];
    }

    public static void sendStaleDealsNotification() {
        List<Deal__c> staleDeals = getStaleDeals();
        for (Deal__c deal : staleDeals) {
            System.debug('Stale deal reminder: ' + deal.Name + ' last modified ' + deal.LastModifiedDate);
        }
    }
}
