/**
 * Controller for the Next Best Action LWC component.
 * Evaluates NBA_Rule__mdt rules against the current Opportunity
 * and returns sorted recommendation cards.
 */
public with sharing class NextBestActionController {

    /**
     * Retrieves evaluated and sorted NBA recommendations for an Opportunity.
     * @param opportunityId The Id of the Opportunity to evaluate rules against.
     * @param dismissedLabels List of Action_Label values already dismissed by the user.
     * @return List<RecommendationWrapper> sorted by Priority ascending.
     */
    @AuraEnabled(cacheable=false)
    public static List<RecommendationWrapper> getRecommendations(
        Id opportunityId,
        List<String> dismissedLabels
    ) {
        if (opportunityId == null) {
            throw new AuraHandledException('opportunityId is required.');
        }

        List<NBA_Rule__mdt> rules = [
            SELECT
                DeveloperName,
                MasterLabel,
                Condition_Field__c,
                Operator__c,
                Value__c,
                Action_Label__c,
                Action_Type__c,
                Priority__c,
                Action_Payload__c
            FROM NBA_Rule__mdt
            WHERE Is_Active__c = TRUE
            ORDER BY Priority__c ASC NULLS LAST
        ];

        Opportunity opp = fetchOpportunity(opportunityId);

        Set<String> dismissed = dismissedLabels != null
            ? new Set<String>(dismissedLabels)
            : new Set<String>();

        List<RecommendationWrapper> results = new List<RecommendationWrapper>();

        for (NBA_Rule__mdt rule : rules) {
            if (dismissed.contains(rule.Action_Label__c)) {
                continue;
            }
            if (evaluateRule(rule, opp)) {
                RecommendationWrapper rec = new RecommendationWrapper();
                rec.actionLabel    = rule.Action_Label__c;
                rec.actionType     = rule.Action_Type__c;
                rec.priority       = rule.Priority__c != null ? rule.Priority__c.intValue() : 99;
                rec.actionPayload  = rule.Action_Payload__c;
                rec.developerName  = rule.DeveloperName;
                results.add(rec);
            }
        }

        results.sort();
        return results;
    }

    /**
     * Creates a follow-up Task on an Opportunity as part of a Take Action flow.
     * @param opportunityId The Opportunity Id to attach the task to.
     * @param subject       Task subject line.
     * @return Id of the created Task.
     */
    @AuraEnabled
    public static Id createFollowUpTask(Id opportunityId, String subject) {
        if (opportunityId == null || String.isBlank(subject)) {
            throw new AuraHandledException('opportunityId and subject are required.');
        }
        Task t = new Task(
            WhatId     = opportunityId,
            Subject    = subject,
            Status     = 'Not Started',
            Priority   = 'Normal',
            ActivityDate = Date.today().addDays(3)
        );
        insert t;
        return t.Id;
    }

    // ─── Private Helpers ────────────────────────────────────────────────────

    /**
     * Fetches the Opportunity with all fields referenced by NBA rules.
     */
    private static Opportunity fetchOpportunity(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT
                Id,
                Name,
                StageName,
                Amount,
                Probability,
                CloseDate,
                Type,
                LeadSource,
                NextStep,
                HasOpportunityLineItem,
                HasOverdueTask,
                IsClosed,
                IsWon,
                ForecastCategory,
                MainCompetitors__c,
                CurrentGenerators__c,
                DeliveryInstallationStatus__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw new AuraHandledException('Opportunity not found: ' + opportunityId);
        }
        return opps[0];
    }

    /**
     * Evaluates a single NBA_Rule__mdt record against the Opportunity.
     */
    private static Boolean evaluateRule(NBA_Rule__mdt rule, Opportunity opp) {
        if (String.isBlank(rule.Condition_Field__c) || String.isBlank(rule.Operator__c)) {
            return false;
        }

        Object fieldValue;
        try {
            fieldValue = opp.get(rule.Condition_Field__c);
        } catch (SObjectException e) {
            return false;
        }

        String operator   = rule.Operator__c.trim().toLowerCase();
        String ruleValue  = rule.Value__c;

        if (operator == 'not_blank') {
            return fieldValue != null && String.isNotBlank(String.valueOf(fieldValue));
        }
        if (operator == 'is_blank') {
            return fieldValue == null || String.isBlank(String.valueOf(fieldValue));
        }

        if (fieldValue == null || ruleValue == null) {
            return false;
        }

        if (fieldValue instanceof Boolean) {
            return compareBooleans((Boolean) fieldValue, ruleValue, operator);
        }
        if (fieldValue instanceof Decimal || fieldValue instanceof Integer || fieldValue instanceof Long) {
            return compareDecimals(((Decimal) fieldValue), Decimal.valueOf(ruleValue), operator);
        }
        if (fieldValue instanceof Date) {
            return compareDates((Date) fieldValue, Date.valueOf(ruleValue), operator);
        }
        // Default: string comparison
        return compareStrings(String.valueOf(fieldValue), ruleValue, operator);
    }

    private static Boolean compareStrings(String fieldVal, String ruleVal, String operator) {
        switch on operator {
            when 'equals'       { return fieldVal.equalsIgnoreCase(ruleVal); }
            when 'not_equals'   { return !fieldVal.equalsIgnoreCase(ruleVal); }
            when 'contains'     { return fieldVal.toLowerCase().contains(ruleVal.toLowerCase()); }
            when 'not_contains' { return !fieldVal.toLowerCase().contains(ruleVal.toLowerCase()); }
            when 'starts_with'  { return fieldVal.toLowerCase().startsWith(ruleVal.toLowerCase()); }
            when else           { return false; }
        }
    }

    private static Boolean compareDecimals(Decimal fieldVal, Decimal ruleVal, String operator) {
        switch on operator {
            when 'equals'               { return fieldVal == ruleVal; }
            when 'not_equals'           { return fieldVal != ruleVal; }
            when 'greater_than'         { return fieldVal > ruleVal; }
            when 'less_than'            { return fieldVal < ruleVal; }
            when 'greater_than_equals'  { return fieldVal >= ruleVal; }
            when 'less_than_equals'     { return fieldVal <= ruleVal; }
            when else                   { return false; }
        }
    }

    private static Boolean compareDates(Date fieldVal, Date ruleVal, String operator) {
        switch on operator {
            when 'equals'               { return fieldVal == ruleVal; }
            when 'not_equals'           { return fieldVal != ruleVal; }
            when 'greater_than'         { return fieldVal > ruleVal; }
            when 'less_than'            { return fieldVal < ruleVal; }
            when 'greater_than_equals'  { return fieldVal >= ruleVal; }
            when 'less_than_equals'     { return fieldVal <= ruleVal; }
            when else                   { return false; }
        }
    }

    private static Boolean compareBooleans(Boolean fieldVal, String ruleVal, String operator) {
        Boolean ruleValBool = (ruleVal.trim().equalsIgnoreCase('true'));
        switch on operator {
            when 'equals'     { return fieldVal == ruleValBool; }
            when 'not_equals' { return fieldVal != ruleValBool; }
            when else         { return false; }
        }
    }

    // ─── Inner Classes ───────────────────────────────────────────────────────

    /**
     * Wrapper representing a single NBA recommendation card.
     * Implements Comparable to allow native List.sort() by priority.
     */
    public class RecommendationWrapper implements Comparable {
        @AuraEnabled public String  actionLabel   { get; set; }
        @AuraEnabled public String  actionType    { get; set; }
        @AuraEnabled public Integer priority      { get; set; }
        @AuraEnabled public String  actionPayload { get; set; }
        @AuraEnabled public String  developerName { get; set; }

        public Integer compareTo(Object other) {
            RecommendationWrapper that = (RecommendationWrapper) other;
            Integer thisPriority = this.priority != null ? this.priority : 99;
            Integer thatPriority = that.priority != null ? that.priority : 99;
            if (thisPriority < thatPriority) { return -1; }
            if (thisPriority > thatPriority) { return  1; }
            return 0;
        }
    }
}