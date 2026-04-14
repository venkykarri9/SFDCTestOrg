public with sharing class DealTriggerHandler {

    public static void handleBeforeInsert(List<Deal__c> newDeals) {
        setDefaultValues(newDeals);
        validateRequiredFields(newDeals);
    }

    public static void handleBeforeUpdate(List<Deal__c> newDeals, Map<Id, Deal__c> oldDeals) {
        validateStageTransition(newDeals, oldDeals);
        updateProbability(newDeals, oldDeals);
    }

    public static void handleAfterInsert(List<Deal__c> newDeals) {
        createWelcomeActivity(newDeals);
    }

    public static void handleAfterUpdate(List<Deal__c> newDeals, Map<Id, Deal__c> oldDeals) {
        notifyOnClose(newDeals, oldDeals);
        updateForecast(newDeals, oldDeals);
    }

    private static void setDefaultValues(List<Deal__c> deals) {
        for (Deal__c deal : deals) {
            if (deal.Win_Probability__c == null) {
                deal.Win_Probability__c = 10;
            }
            if (deal.Deal_Stage__c == null) {
                deal.Deal_Stage__c = 'Prospecting';
            }
        }
    }

    private static void validateRequiredFields(List<Deal__c> deals) {
        for (Deal__c deal : deals) {
            if (deal.Close_Date__c < Date.today()) {
                deal.addError('Close Date cannot be in the past');
            }
            if (deal.Account__c == null) {
                deal.addError('Account is required for new deals');
            }
        }
    }

    private static void validateStageTransition(List<Deal__c> newDeals, Map<Id, Deal__c> oldDeals) {
        for (Deal__c deal : newDeals) {
            Deal__c oldDeal = oldDeals.get(deal.Id);
            if (oldDeal.Deal_Stage__c == 'Closed Won' && deal.Deal_Stage__c != 'Closed Won') {
                deal.addError('Cannot change stage from Closed Won');
            }
        }
    }

    private static void updateProbability(List<Deal__c> newDeals, Map<Id, Deal__c> oldDeals) {
        Map<String, Integer> stageProbability = new Map<String, Integer>{
            'Prospecting' => 10,
            'Qualification' => 25,
            'Proposal' => 50,
            'Negotiation' => 75,
            'Closed Won' => 100,
            'Closed Lost' => 0
        };
        for (Deal__c deal : newDeals) {
            if (deal.Deal_Stage__c != oldDeals.get(deal.Id).Deal_Stage__c) {
                if (stageProbability.containsKey(deal.Deal_Stage__c)) {
                    deal.Win_Probability__c = stageProbability.get(deal.Deal_Stage__c);
                }
            }
        }
    }

    private static void createWelcomeActivity(List<Deal__c> deals) {
        List<Deal_Activity__c> activities = new List<Deal_Activity__c>();
        for (Deal__c deal : deals) {
            activities.add(new Deal_Activity__c(
                Deal__c = deal.Id,
                Activity_Type__c = 'Call',
                Activity_Date__c = DateTime.now(),
                Outcome__c = 'Neutral',
                Notes__c = 'Initial contact - deal created',
                Completed__c = false
            ));
        }
        if (!activities.isEmpty()) insert activities;
    }

    private static void notifyOnClose(List<Deal__c> newDeals, Map<Id, Deal__c> oldDeals) {
        for (Deal__c deal : newDeals) {
            if (deal.Deal_Stage__c == 'Closed Won' &&
                oldDeals.get(deal.Id).Deal_Stage__c != 'Closed Won') {
                // Notify team of closed deal
                System.debug('Deal closed: ' + deal.Id);
            }
        }
    }

    private static void updateForecast(List<Deal__c> newDeals, Map<Id, Deal__c> oldDeals) {
        List<Deal__c> closedWonDeals = new List<Deal__c>();
        for (Deal__c deal : newDeals) {
            if (deal.Deal_Stage__c == 'Closed Won' &&
                oldDeals.get(deal.Id).Deal_Stage__c != 'Closed Won') {
                closedWonDeals.add(deal);
            }
        }
        if (closedWonDeals.isEmpty()) return;

        // Re-query to get Territory__c and Deal_Value__c (after-trigger context)
        Map<Id, Deal__c> dealDetails = new Map<Id, Deal__c>([
            SELECT Id, Territory__c, Deal_Value__c
            FROM Deal__c
            WHERE Id IN :closedWonDeals
        ]);

        Date firstOfMonth = Date.today().toStartOfMonth();
        Set<Id> territoryIds = new Set<Id>();
        for (Deal__c d : dealDetails.values()) {
            if (d.Territory__c != null) territoryIds.add(d.Territory__c);
        }
        if (territoryIds.isEmpty()) return;

        List<Sales_Forecast__c> forecasts = [
            SELECT Id, Territory__c, Actual_Amount__c
            FROM Sales_Forecast__c
            WHERE Territory__c IN :territoryIds AND Forecast_Month__c = :firstOfMonth
        ];
        Map<Id, Sales_Forecast__c> forecastByTerritory = new Map<Id, Sales_Forecast__c>();
        for (Sales_Forecast__c f : forecasts) {
            forecastByTerritory.put(f.Territory__c, f);
        }

        List<Sales_Forecast__c> forecastsToUpdate = new List<Sales_Forecast__c>();
        for (Deal__c deal : dealDetails.values()) {
            if (deal.Territory__c != null && forecastByTerritory.containsKey(deal.Territory__c)) {
                Sales_Forecast__c forecast = forecastByTerritory.get(deal.Territory__c);
                if (forecast.Actual_Amount__c == null) forecast.Actual_Amount__c = 0;
                forecast.Actual_Amount__c += (deal.Deal_Value__c != null ? deal.Deal_Value__c : 0);
                forecastsToUpdate.add(forecast);
            }
        }
        if (!forecastsToUpdate.isEmpty()) update forecastsToUpdate;
    }
}
