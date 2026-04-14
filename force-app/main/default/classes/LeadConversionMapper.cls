/**
 * @description Service class responsible for mapping custom Lead fields to their corresponding
 *              Opportunity and Contact fields immediately after Lead conversion.
 *
 *              Field mappings:
 *                Lead.Budget_Range__c     → Opportunity.Budget__c
 *                Lead.Decision_Timeline__c → Opportunity.Decision_Date__c
 *                Lead.Tech_Stack__c        → Contact.Tech_Stack__c
 *
 *              Design decisions:
 *                - Only fires when IsConverted transitions from false → true
 *                - Issues exactly 2 SOQL queries (one for Opportunity, one for Contact)
 *                - Null source values on the Lead do NOT overwrite existing target values
 *                - DML exceptions are intentionally not caught; failures roll back the transaction
 *                - ConvertedOpportunityId null check handles private conversions (no Opp created)
 */
public with sharing class LeadConversionMapper {

    /**
     * @description Entry point called by LeadTrigger. Filters the incoming list to only
     *              Leads that have just been converted in this transaction, then orchestrates
     *              the field-mapping DML for Opportunities and Contacts.
     *
     * @param newLeads  Trigger.new — full list of updated Lead records
     * @param oldMap    Trigger.oldMap — pre-update Lead records keyed by Id
     */
    public static void mapConvertedLeads(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        List<Lead> justConverted = new List<Lead>();
        for (Lead l : newLeads) {
            Lead oldLead = oldMap.get(l.Id);
            if (l.IsConverted && !oldLead.IsConverted) {
                justConverted.add(l);
            }
        }

        if (justConverted.isEmpty()) {
            return;
        }

        // Collect target record Ids
        Set<Id> oppIds     = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (Lead l : justConverted) {
            if (l.ConvertedOpportunityId != null) {
                oppIds.add(l.ConvertedOpportunityId);
            }
            if (l.ConvertedContactId != null) {
                contactIds.add(l.ConvertedContactId);
            }
        }

        // SOQL 1 — Opportunity targets (only when at least one Opp was created)
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        if (!oppIds.isEmpty()) {
            oppMap = new Map<Id, Opportunity>(
                [SELECT Id, Budget__c, Decision_Date__c
                 FROM   Opportunity
                 WHERE  Id IN :oppIds]
            );
        }

        // SOQL 2 — Contact targets
        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            contactMap = new Map<Id, Contact>(
                [SELECT Id, Tech_Stack__c
                 FROM   Contact
                 WHERE  Id IN :contactIds]
            );
        }

        List<Opportunity> oppsToUpdate     = buildOpportunityUpdates(justConverted, oppMap);
        List<Contact>     contactsToUpdate = buildContactUpdates(justConverted, contactMap);

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    /**
     * @description Builds a list of Opportunity records to update with mapped Lead field values.
     *              Skips assignment if the source Lead field is null (AC-5).
     *
     * @param leads  Leads that were just converted
     * @param oppMap Map of Opportunity records keyed by Id, pre-queried outside this method
     * @return       List of Opportunity records with updated fields; may be empty
     */
    @TestVisible
    private static List<Opportunity> buildOpportunityUpdates(
        List<Lead> leads,
        Map<Id, Opportunity> oppMap
    ) {
        List<Opportunity> toUpdate = new List<Opportunity>();

        for (Lead l : leads) {
            if (l.ConvertedOpportunityId == null) {
                continue;
            }
            Opportunity opp = oppMap.get(l.ConvertedOpportunityId);
            if (opp == null) {
                continue;
            }

            Boolean dirty = false;

            // AC-1: Budget_Range__c → Budget__c
            if (l.Budget_Range__c != null) {
                opp.Budget__c = l.Budget_Range__c;
                dirty = true;
            }

            // AC-2: Decision_Timeline__c → Decision_Date__c
            if (l.Decision_Timeline__c != null) {
                opp.Decision_Date__c = l.Decision_Timeline__c;
                dirty = true;
            }

            if (dirty) {
                toUpdate.add(opp);
            }
        }

        return toUpdate;
    }

    /**
     * @description Builds a list of Contact records to update with mapped Lead field values.
     *              Skips assignment if the source Lead field is null (AC-5).
     *
     * @param leads      Leads that were just converted
     * @param contactMap Map of Contact records keyed by Id, pre-queried outside this method
     * @return           List of Contact records with updated fields; may be empty
     */
    @TestVisible
    private static List<Contact> buildContactUpdates(
        List<Lead> leads,
        Map<Id, Contact> contactMap
    ) {
        List<Contact> toUpdate = new List<Contact>();

        for (Lead l : leads) {
            if (l.ConvertedContactId == null) {
                continue;
            }
            Contact con = contactMap.get(l.ConvertedContactId);
            if (con == null) {
                continue;
            }

            // AC-3: Tech_Stack__c → Contact.Tech_Stack__c
            if (l.get('Tech_Stack__c') != null) {
                con.put('Tech_Stack__c', l.get('Tech_Stack__c'));
                toUpdate.add(con);
            }
        }

        return toUpdate;
    }
}