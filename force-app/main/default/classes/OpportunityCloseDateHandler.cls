/**
 * @description Handler class for Opportunity close date push notifications.
 *              Detects when a CloseDate is pushed forward by more than 14 days
 *              and publishes a Close_Date_Pushed__e Platform Event.
 * @author      Salesforce Developer
 */
public with sharing class OpportunityCloseDateHandler {

    private static final Integer PUSH_THRESHOLD_DAYS = 14;

    /**
     * @description Evaluates updated Opportunities and publishes platform events
     *              when the CloseDate has been pushed forward by more than 14 days.
     * @param newOpps  List of updated Opportunity records (Trigger.new)
     * @param oldOppMap Map of previous Opportunity state (Trigger.oldMap)
     */
    public static void handleAfterUpdate(
        List<Opportunity> newOpps,
        Map<Id, Opportunity> oldOppMap
    ) {
        List<Close_Date_Pushed__e> events = new List<Close_Date_Pushed__e>();

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);

            if (oldOpp == null || opp.CloseDate == null || oldOpp.CloseDate == null) {
                continue;
            }

            Integer daysDelta = oldOpp.CloseDate.daysBetween(opp.CloseDate);

            if (daysDelta > PUSH_THRESHOLD_DAYS) {
                Close_Date_Pushed__e evt = new Close_Date_Pushed__e(
                    Opportunity_Id__c  = opp.Id,
                    Old_Close_Date__c  = oldOpp.CloseDate,
                    New_Close_Date__c  = opp.CloseDate,
                    Days_Pushed__c     = daysDelta,
                    Rep_Name__c        = opp.Owner_Full_Name__c
                );
                events.add(evt);
            }
        }

        if (!events.isEmpty()) {
            publishEvents(events);
        }
    }

    /**
     * @description Publishes a list of Close_Date_Pushed__e platform events.
     *              Logs any publish errors to the debug log.
     * @param events List of platform events to publish
     */
    @TestVisible
    private static void publishEvents(List<Close_Date_Pushed__e> events) {
        List<Database.SaveResult> results = EventBus.publish(events);
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Failed to publish Close_Date_Pushed__e for event index ' + i +
                        ': ' + err.getStatusCode() + ' - ' + err.getMessage());
                }
            }
        }
    }
}