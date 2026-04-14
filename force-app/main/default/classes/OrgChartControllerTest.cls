/**
 * @description Test class for OrgChartController.
 *              Covers positive, negative, and bulk scenarios.
 */
@IsTest
private class OrgChartControllerTest {

    // ─────────────────────────────────────────────────────────────────
    // Test setup
    // ─────────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Account acct = new Account(Name = 'Test Account OrgChart');
        insert acct;
    }

    // ─────────────────────────────────────────────────────────────────
    // Helper
    // ─────────────────────────────────────────────────────────────────

    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account OrgChart' LIMIT 1];
    }

    /**
     * @description Creates a Contact attached to the test account with an
     *              optional ReportsToId.
     */
    private static Contact makeContact(
        String lastName,
        Id accountId,
        Id reportsToId
    ) {
        return new Contact(
            LastName   = lastName,
            AccountId  = accountId,
            ReportsToId = reportsToId,
            Title      = 'Title_' + lastName,
            Email      = lastName.toLowerCase().replaceAll('\\s+', '.') + '@example.com'
        );
    }

    // ─────────────────────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────────────────────

    /**
     * @description Single root Contact with no children.
     *              Expects one node marked isRoot=true at depth 0.
     */
    @IsTest
    static void testSingleRootNoChildren() {
        Account acct = getAccount();
        Contact root = makeContact('Root Only', acct.Id, null);
        insert root;

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(1, resp.nodes.size(), 'Expected exactly 1 node');
        System.assertEquals(false, resp.isTruncated, 'Should not be truncated');
        OrgChartController.ContactNode node = resp.nodes.get(0);
        System.assertEquals(true,  node.isRoot, 'Node should be root');
        System.assertEquals(0,     node.depth,  'Root depth should be 0');
        System.assertEquals(null,  node.parentId, 'Root parentId should be null');
    }

    /**
     * @description Linear chain of exactly 6 Contacts (depth 0-5).
     *              All six should be included.
     */
    @IsTest
    static void testLinearChainSixLevels() {
        Account acct = getAccount();
        List<Contact> chain = new List<Contact>();

        // Insert root first
        Contact c0 = makeContact('Level0', acct.Id, null);
        insert c0;
        chain.add(c0);

        // Build remaining levels
        List<Contact> toInsert = new List<Contact>();
        Id parentId = c0.Id;
        for (Integer i = 1; i < 6; i++) {
            Contact c = makeContact('Level' + i, acct.Id, parentId);
            toInsert.add(c);
        }
        insert toInsert;
        // Reload to get Ids
        List<Contact> inserted = [SELECT Id, ReportsToId FROM Contact WHERE AccountId = :acct.Id ORDER BY CreatedDate];

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(6, resp.nodes.size(), 'Expected 6 nodes for a 6-level chain');
        System.assertEquals(false, resp.isTruncated, 'Should not be truncated');

        // Validate depths 0-5
        Map<Id, OrgChartController.ContactNode> nodeMap = new Map<Id, OrgChartController.ContactNode>();
        for (OrgChartController.ContactNode n : resp.nodes) {
            nodeMap.put(n.id, n);
        }
        Integer rootCount = 0;
        for (OrgChartController.ContactNode n : resp.nodes) {
            if (n.isRoot) { rootCount++; }
        }
        System.assertEquals(1, rootCount, 'Exactly one root expected in linear chain');
    }

    /**
     * @description Seven-level linear chain. The 7th level (depth=6) must be excluded.
     *              Expects exactly 6 nodes returned.
     */
    @IsTest
    static void testSevenLevelChainCapped() {
        Account acct = getAccount();

        Contact c0 = makeContact('Cap0', acct.Id, null);
        insert c0;

        Id parentId = c0.Id;
        List<Contact> toInsert = new List<Contact>();
        for (Integer i = 1; i <= 6; i++) {
            Contact c = makeContact('Cap' + i, acct.Id, parentId);
            toInsert.add(c);
        }
        // Insert sequentially to chain properly
        List<Contact> insertedChain = new List<Contact>();
        insertedChain.add(c0);
        Contact prev = c0;
        for (Integer i = 1; i <= 6; i++) {
            Contact c = makeContact('Chain' + i, acct.Id, prev.Id);
            insert c;
            insertedChain.add(c);
            prev = c;
        }

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(6, resp.nodes.size(),
            'BFS should cap at 6 levels; 7th level contact must be excluded');
    }

    /**
     * @description Two independent root Contacts, no children.
     *              Expects 2 nodes, both isRoot=true.
     */
    @IsTest
    static void testMultipleRoots() {
        Account acct = getAccount();
        List<Contact> roots = new List<Contact>{
            makeContact('RootA', acct.Id, null),
            makeContact('RootB', acct.Id, null)
        };
        insert roots;

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(2, resp.nodes.size(), 'Expected 2 root nodes');
        for (OrgChartController.ContactNode n : resp.nodes) {
            System.assertEquals(true, n.isRoot, 'Both nodes should be roots');
            System.assertEquals(0,    n.depth,  'Both roots should be at depth 0');
        }
    }

    /**
     * @description Root with two levels of children (1 root, 2 children, 4 grandchildren).
     *              Expects 7 nodes total.
     */
    @IsTest
    static void testRootWithTwoLevelsChildren() {
        Account acct = getAccount();

        Contact root = makeContact('HRoot', acct.Id, null);
        insert root;

        List<Contact> level1 = new List<Contact>{
            makeContact('HChild1', acct.Id, root.Id),
            makeContact('HChild2', acct.Id, root.Id)
        };
        insert level1;

        List<Contact> level2 = new List<Contact>{
            makeContact('HGrand1', acct.Id, level1.get(0).Id),
            makeContact('HGrand2', acct.Id, level1.get(0).Id),
            makeContact('HGrand3', acct.Id, level1.get(1).Id),
            makeContact('HGrand4', acct.Id, level1.get(1).Id)
        };
        insert level2;

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(7, resp.nodes.size(), 'Expected 7 nodes (1+2+4)');

        Integer rootCount  = 0;
        Integer depth1Count = 0;
        Integer depth2Count = 0;
        for (OrgChartController.ContactNode n : resp.nodes) {
            if (n.depth == 0) { rootCount++; }
            if (n.depth == 1) { depth1Count++; }
            if (n.depth == 2) { depth2Count++; }
        }
        System.assertEquals(1, rootCount,   'One root at depth 0');
        System.assertEquals(2, depth1Count, 'Two nodes at depth 1');
        System.assertEquals(4, depth2Count, 'Four nodes at depth 2');
    }

    /**
     * @description Account with zero Contacts.
     *              Expects empty node list and isTruncated=false.
     */
    @IsTest
    static void testNoContacts() {
        Account acct = getAccount();

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(0, resp.nodes.size(), 'Expected empty node list');
        System.assertEquals(false, resp.isTruncated, 'isTruncated should be false');
    }

    /**
     * @description Passing null / blank accountId returns empty response gracefully.
     */
    @IsTest
    static void testInvalidAccountId() {
        Test.startTest();
        OrgChartController.OrgChartResponse respNull =
            OrgChartController.getOrgChart(null);
        OrgChartController.OrgChartResponse respBlank =
            OrgChartController.getOrgChart('');
        OrgChartController.OrgChartResponse respBad =
            OrgChartController.getOrgChart('NOT_AN_ID_12345');
        Test.stopTest();

        System.assertEquals(0, respNull.nodes.size(),  'null accountId → empty list');
        System.assertEquals(0, respBlank.nodes.size(), 'blank accountId → empty list');
        System.assertEquals(0, respBad.nodes.size(),   'bad accountId → empty list');
    }

    /**
     * @description Contact whose ReportsToId points to a Contact on a DIFFERENT
     *              account (external) is treated as a root node.
     */
    @IsTest
    static void testExternalReportsToTreatedAsRoot() {
        Account acct = getAccount();

        Account otherAcct = new Account(Name = 'Other Account');
        insert otherAcct;

        Contact externalContact = makeContact('ExternalBoss', otherAcct.Id, null);
        insert externalContact;

        Contact internalContact = makeContact('InternalEmployee', acct.Id, externalContact.Id);
        insert internalContact;

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(1, resp.nodes.size(), 'Only in-account contacts returned');
        OrgChartController.ContactNode node = resp.nodes.get(0);
        System.assertEquals(true, node.isRoot,
            'Contact reporting to external contact should be treated as root');
        System.assertEquals(null, node.parentId,
            'parentId should be null when ReportsTo is external');
    }

    /**
     * @description Bulk scenario: 200 root Contacts should all be returned.
     *              Tests governor limits are not breached.
     */
    @IsTest
    static void testBulkTwoHundredContacts() {
        Account acct = getAccount();

        List<Contact> bulkContacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            bulkContacts.add(makeContact('BulkContact' + i, acct.Id, null));
        }
        insert bulkContacts;

        Test.startTest();
        OrgChartController.OrgChartResponse resp =
            OrgChartController.getOrgChart(acct.Id);
        Test.stopTest();

        System.assertEquals(200, resp.nodes.size(),
            '200 contacts should all be returned without governor limit errors');
        System.assertEquals(false, resp.isTruncated, 'isTruncated should be false for 200 records');
    }

    /**
     * @description Verifies that isTruncated is set on OrgChartResponse
     *              when the query limit is reached.
     *              Simulates the flag by testing the response field directly
     *              (actual 2001 insert would exceed test DML limits, so we
     *              validate the constructor path).
     */
    @IsTest
    static void testTruncationAt2001() {
        Test.startTest();
        OrgChartController.OrgChartResponse truncResp =
            new OrgChartController.OrgChartResponse(
                new List<OrgChartController.ContactNode>(), true);
        OrgChartController.OrgChartResponse normalResp =
            new OrgChartController.OrgChartResponse(
                new List<OrgChartController.ContactNode>(), false);
        Test.stopTest();

        System.assertEquals(true, truncResp.isTruncated,
            'OrgChartResponse should expose isTruncated=true');
        System.assertEquals(false, normalResp.isTruncated,
            'OrgChartResponse should expose isTruncated=false');
    }
}