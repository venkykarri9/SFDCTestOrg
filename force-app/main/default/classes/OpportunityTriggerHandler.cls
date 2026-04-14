/**
 * @description Handler class for OpportunityTrigger.
 * Detects when an Opportunity CloseDate has been pushed forward by more than 14 days
 * and publishes a Close_Date_Pushed__e Platform Event for each qualifying record.
 */
public with sharing class OpportunityTriggerHandler {

    /** Number of days delta that qualifies as a "pushed" close date. */
    private static final Integer PUSH_THRESHOLD_DAYS = 14;

    /**
     * @description Entry point called from the after-update trigger context.
     * Identifies opportunities whose CloseDate has moved forward by more than
     * PUSH_THRESHOLD_DAYS days and publishes a Platform Event for each one.
     *
     * @param newList  List of updated Opportunity records (Trigger.new)
     * @param oldMap   Map of Opportunity records before the update (Trigger.oldMap)
     */
    public static void handleAfterUpdate(
            List<Opportunity> newList,
            Map<Id, Opportunity> oldMap) {

        List<Close_Date_Pushed__e> events = buildEvents(newList, oldMap);

        if (!events.isEmpty()) {
            publishEvents(events);
        }
    }

    /**
     * @description Iterates the updated opportunities and builds Platform Event records
     * for any whose CloseDate has moved forward by more than PUSH_THRESHOLD_DAYS.
     *
     * @param newList  List of updated Opportunity records
     * @param oldMap   Map of prior-state Opportunity records
     * @return         List of Close_Date_Pushed__e events ready for publication
     */
    @TestVisible
    private static List<Close_Date_Pushed__e> buildEvents(
            List<Opportunity> newList,
            Map<Id, Opportunity> oldMap) {

        List<Close_Date_Pushed__e> events = new List<Close_Date_Pushed__e>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            if (oldOpp == null || opp.CloseDate == null || oldOpp.CloseDate == null) {
                continue;
            }

            Integer daysDelta = oldOpp.CloseDate.daysBetween(opp.CloseDate);

            if (daysDelta > PUSH_THRESHOLD_DAYS) {
                Close_Date_Pushed__e evt = new Close_Date_Pushed__e(
                    Opportunity_Id__c = opp.Id,
                    Old_Close_Date__c = oldOpp.CloseDate,
                    New_Close_Date__c = opp.CloseDate,
                    Days_Pushed__c    = daysDelta,
                    Rep_Name__c       = opp.Owner_Full_Name__c
                );
                events.add(evt);
            }
        }

        return events;
    }

    /**
     * @description Publishes a list of Close_Date_Pushed__e Platform Events.
     * Logs any partial save errors to the debug log without throwing, so that
     * the originating DML operation is not rolled back by event-publish failures.
     *
     * @param events  Non-empty list of Platform Events to publish
     */
    private static void publishEvents(List<Close_Date_Pushed__e> events) {
        List<Database.SaveResult> results = EventBus.publish(events);

        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Close_Date_Pushed__e publish failed for index ' + i +
                        ': [' + err.getStatusCode() + '] ' + err.getMessage());
                }
            }
        }
    }
}