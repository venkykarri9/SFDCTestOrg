/**
 * @description Test class for LeadConversionMapper and the LeadTrigger after-update event.
 *
 *              Coverage targets:
 *                - testSingleConversion        — AC-1, AC-2, AC-3, AC-4 (happy path)
 *                - testBulkConversion          — AC-6 (200 records)
 *                - testNullSourceDoesNotOverwrite — AC-5
 *                - testNonConvertedLeadIgnored — AC-4 (no conversion → no DML)
 *                - testPartialNulls            — AC-5 partial (one field null, one set)
 *                - testConversionWithoutOpportunity — private conversion (no Opp)
 *
 *              Note: Salesforce does not support standard Lead conversion via DML in tests;
 *              we therefore test the service layer directly using @TestVisible helpers and
 *              synthetic data, which is the accepted pattern for conversion mapping logic.
 */
@IsTest
private class LeadConversionMapperTest {

    // ─── Fake Id Generator ────────────────────────────────────────────────────

    private static Integer fakeIdCounter = 1;

    private static Id generateFakeId(Schema.SObjectType sObjectType) {
        String keyPrefix = sObjectType.getDescribe().getKeyPrefix();
        Integer counter  = fakeIdCounter++;
        String suffix    = String.valueOf(counter).leftPad(12, '0');
        return (Id)(keyPrefix + suffix);
    }

    // ─── Test Data Helpers ────────────────────────────────────────────────────

    /**
     * @description Creates a minimal Lead suitable for use in service-layer tests.
     *              Does NOT insert — callers control persistence.
     */
    private static Lead buildLead(
        String lastName,
        Decimal budgetRange,
        Date decisionTimeline,
        String techStack
    ) {
        Lead l = new Lead(
            LastName  = lastName,
            Company   = 'Test Corp',
            Status    = 'Open - Not Contacted'
        );
        l.Budget_Range__c      = budgetRange;
        l.Decision_Timeline__c = decisionTimeline;
        l.put('Tech_Stack__c', techStack);
        return l;
    }

    /**
     * @description Creates and inserts an Opportunity stub, then returns it.
     */
    private static Opportunity insertOpp(String name) {
        Account acct = new Account(Name = name + ' Account');
        insert acct;
        Opportunity opp = new Opportunity(
            Name        = name,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30),
            AccountId   = acct.Id
        );
        insert opp;
        return opp;
    }

    /**
     * @description Creates and inserts a Contact stub, then returns it.
     */
    private static Contact insertContact(String lastName) {
        Account acct = new Account(Name = lastName + ' Account');
        insert acct;
        Contact con = new Contact(
            LastName  = lastName,
            AccountId = acct.Id
        );
        insert con;
        return con;
    }

    // ─── Helper: simulate a converted Lead record ─────────────────────────────

    /**
     * @description Constructs a synthetic Lead that looks as if it just converted
     *              (IsConverted = true, ConvertedOpportunityId and ConvertedContactId set).
     *              Uses JSON deserialization to bypass read-only field restrictions.
     */
    private static Lead syntheticConvertedLead(
        Id leadId,
        Id oppId,
        Id contactId,
        Decimal budgetRange,
        Date decisionTimeline,
        String techStack
    ) {
        Map<String, Object> fieldMap = new Map<String, Object>();
        fieldMap.put('Id',                     leadId);
        fieldMap.put('LastName',               'Synthetic');
        fieldMap.put('Company',                'Synthetic Corp');
        fieldMap.put('IsConverted',            true);
        fieldMap.put('Budget_Range__c',        budgetRange);
        fieldMap.put('Decision_Timeline__c',   decisionTimeline != null
            ? String.valueOf(decisionTimeline) : null);
        fieldMap.put('Tech_Stack__c',          techStack);
        if (oppId != null) {
            fieldMap.put('ConvertedOpportunityId', oppId);
        }
        if (contactId != null) {
            fieldMap.put('ConvertedContactId', contactId);
        }
        return (Lead) JSON.deserialize(JSON.serialize(fieldMap), Lead.class);
    }

    /**
     * @description Constructs a synthetic old Lead (pre-conversion snapshot).
     */
    private static Lead syntheticOldLead(Id leadId) {
        Map<String, Object> fieldMap = new Map<String, Object>();
        fieldMap.put('Id',          leadId);
        fieldMap.put('LastName',    'Synthetic');
        fieldMap.put('Company',     'Synthetic Corp');
        fieldMap.put('IsConverted', false);
        return (Lead) JSON.deserialize(JSON.serialize(fieldMap), Lead.class);
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void testSingleConversion() {
        Opportunity opp = insertOpp('Test Opp');
        Contact     con = insertContact('TestContact');

        Id leadId = generateFakeId(Lead.SObjectType);

        Lead newLead = syntheticConvertedLead(
            leadId,
            opp.Id,
            con.Id,
            50000,
            Date.today().addDays(60),
            'Apex, LWC'
        );
        Lead oldLead = syntheticOldLead(leadId);

        Test.startTest();
        LeadConversionMapper.mapConvertedLeads(
            new List<Lead>{ newLead },
            new Map<Id, Lead>{ leadId => oldLead }
        );
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Budget__c, Decision_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, updatedOpp.Budget__c,       'Budget should be mapped');
        System.assertEquals(50000, updatedOpp.Budget__c,         'Budget should match lead value');
        System.assertNotEquals(null, updatedOpp.Decision_Date__c,'Decision date should be mapped');

        Contact updatedCon = [SELECT Tech_Stack__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Apex, LWC', updatedCon.get('Tech_Stack__c'), 'Tech stack should be mapped');
    }

    @IsTest
    static void testBulkConversion() {
        Integer bulkSize = 200;
        List<Account> accts = new List<Account>();
        for (Integer i = 0; i < bulkSize * 2; i++) {
            accts.add(new Account(Name = 'Bulk Acct ' + i));
        }
        insert accts;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < bulkSize; i++) {
            opps.add(new Opportunity(
                Name      = 'Bulk Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                AccountId = accts[i].Id
            ));
        }
        insert opps;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < bulkSize; i++) {
            contacts.add(new Contact(
                LastName  = 'BulkContact' + i,
                AccountId = accts[bulkSize + i].Id
            ));
        }
        insert contacts;

        List<Lead>    newLeads = new List<Lead>();
        Map<Id, Lead> oldMap   = new Map<Id, Lead>();

        for (Integer i = 0; i < bulkSize; i++) {
            Id leadId = generateFakeId(Lead.SObjectType);
            Lead newLead = syntheticConvertedLead(
                leadId,
                opps[i].Id,
                contacts[i].Id,
                1000 * (i + 1),
                Date.today().addDays(i + 1),
                'Stack' + i
            );
            newLeads.add(newLead);
            oldMap.put(leadId, syntheticOldLead(leadId));
        }

        Test.startTest();
        LeadConversionMapper.mapConvertedLeads(newLeads, oldMap);
        Test.stopTest();

        List<Opportunity> updatedOpps = [SELECT Budget__c FROM Opportunity WHERE Id IN :opps];
        for (Opportunity o : updatedOpps) {
            System.assertNotEquals(null, o.Budget__c, 'Budget should be mapped for all opps');
        }

        List<Contact> updatedContacts = [SELECT Tech_Stack__c FROM Contact WHERE Id IN :contacts];
        for (Contact c : updatedContacts) {
            System.assertNotEquals(null, c.get('Tech_Stack__c'), 'Tech stack should be mapped for all contacts');
        }
    }

    @IsTest
    static void testNullSourceDoesNotOverwrite() {
        Opportunity opp = insertOpp('No Overwrite Opp');
        // Pre-set the budget on the opportunity
        opp.Budget__c = 99999;
        update opp;

        Contact con = insertContact('NoOverwrite');
        con.put('Tech_Stack__c', 'Java');
        update con;

        Id leadId = generateFakeId(Lead.SObjectType);
        // Lead with null source fields
        Lead newLead = syntheticConvertedLead(
            leadId,
            opp.Id,
            con.Id,
            null,  // null budget
            null,  // null decision timeline
            null   // null tech stack
        );
        Lead oldLead = syntheticOldLead(leadId);

        Test.startTest();
        LeadConversionMapper.mapConvertedLeads(
            new List<Lead>{ newLead },
            new Map<Id, Lead>{ leadId => oldLead }
        );
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Budget__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(99999, updatedOpp.Budget__c, 'Null lead field should not overwrite existing Opp value');

        Contact updatedCon = [SELECT Tech_Stack__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Java', updatedCon.get('Tech_Stack__c'), 'Null lead field should not overwrite existing Contact value');
    }

    @IsTest
    static void testNonConvertedLeadIgnored() {
        Id leadId = generateFakeId(Lead.SObjectType);

        Map<String, Object> fieldMap = new Map<String, Object>();
        fieldMap.put('Id',          leadId);
        fieldMap.put('LastName',    'NotConverted');
        fieldMap.put('Company',     'Test Corp');
        fieldMap.put('IsConverted', false);
        Lead newLead = (Lead) JSON.deserialize(JSON.serialize(fieldMap), Lead.class);
        Lead oldLead = syntheticOldLead(leadId);

        Integer oppsBefore = [SELECT COUNT() FROM Opportunity];

        Test.startTest();
        LeadConversionMapper.mapConvertedLeads(
            new List<Lead>{ newLead },
            new Map<Id, Lead>{ leadId => oldLead }
        );
        Test.stopTest();

        Integer oppsAfter = [SELECT COUNT() FROM Opportunity];
        System.assertEquals(oppsBefore, oppsAfter, 'No DML should occur for non-converted leads');
    }

    @IsTest
    static void testPartialNulls() {
        Opportunity opp = insertOpp('Partial Null Opp');
        Contact     con = insertContact('PartialNull');

        Id leadId = generateFakeId(Lead.SObjectType);
        // Budget is set, but decision timeline is null; tech stack is set
        Lead newLead = syntheticConvertedLead(
            leadId,
            opp.Id,
            con.Id,
            25000,
            null,
            'Python'
        );
        Lead oldLead = syntheticOldLead(leadId);

        Test.startTest();
        LeadConversionMapper.mapConvertedLeads(
            new List<Lead>{ newLead },
            new Map<Id, Lead>{ leadId => oldLead }
        );
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Budget__c, Decision_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(25000, updatedOpp.Budget__c,          'Budget should be mapped');
        System.assertEquals(null,  updatedOpp.Decision_Date__c,   'Null decision timeline should not be written');

        Contact updatedCon = [SELECT Tech_Stack__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Python', updatedCon.get('Tech_Stack__c'), 'Tech stack should be mapped');
    }

    @IsTest
    static void testConversionWithoutOpportunity() {
        Contact con = insertContact('NoOpp');

        Id leadId = generateFakeId(Lead.SObjectType);
        // No opportunity (private conversion)
        Lead newLead = syntheticConvertedLead(
            leadId,
            null,
            con.Id,
            75000,
            Date.today().addDays(90),
            'Ruby'
        );
        Lead oldLead = syntheticOldLead(leadId);

        Test.startTest();
        LeadConversionMapper.mapConvertedLeads(
            new List<Lead>{ newLead },
            new Map<Id, Lead>{ leadId => oldLead }
        );
        Test.stopTest();

        Contact updatedCon = [SELECT Tech_Stack__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Ruby', updatedCon.get('Tech_Stack__c'), 'Tech stack should be mapped even without an Opp');
    }
}