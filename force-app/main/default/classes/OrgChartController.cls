/**
 * @description Apex controller for the Account Org Chart LWC.
 *              Queries Contact hierarchy (ReportsToId) and returns a flat list
 *              of ContactNode wrappers capped at 6 levels deep (BFS).
 *              FLS is respected for Email, Languages__c, and Level__c.
 */
public with sharing class OrgChartController {

    private static final Integer MAX_DEPTH   = 5; // 0-indexed, so levels 0-5 = 6 levels
    private static final Integer QUERY_LIMIT = 2000;

    // ─────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────

    /**
     * @description Returns the org-chart data for all Contacts belonging to
     *              the given Account, limited to 6 hierarchy levels.
     * @param  accountId  The Id of the Account record.
     * @return            An OrgChartResponse containing a flat ContactNode list
     *                    and a flag indicating whether the data was truncated.
     */
    @AuraEnabled(cacheable=true)
    public static OrgChartResponse getOrgChart(String accountId) {
        if (String.isBlank(accountId)) {
            return new OrgChartResponse(new List<ContactNode>(), false);
        }

        Id acctId;
        try {
            acctId = (Id) accountId;
        } catch (Exception e) {
            return new OrgChartResponse(new List<ContactNode>(), false);
        }

        // FLS checks
        Boolean canReadEmail     = Schema.sObjectType.Contact.fields.Email.isAccessible();
        Boolean canReadLanguages = Schema.sObjectType.Contact.fields.Languages__c.isAccessible();
        Boolean canReadLevel     = Schema.sObjectType.Contact.fields.Level__c.isAccessible();
        Boolean canReadPhotoUrl  = Schema.sObjectType.Contact.fields.PhotoUrl.isAccessible();

        List<Contact> allContacts = [
            SELECT Id, Name, Title, Email, PhotoUrl, ReportsToId, Languages__c, Level__c
            FROM   Contact
            WHERE  AccountId = :acctId
            AND    IsDeleted  = false
            LIMIT  :QUERY_LIMIT
        ];

        Boolean isTruncated = (allContacts.size() == QUERY_LIMIT);

        // Build lookup maps
        Map<Id, Contact>       contactById       = new Map<Id, Contact>();
        Map<Id, List<Contact>> childrenByParent  = new Map<Id, List<Contact>>();
        Set<Id>                contactIds        = new Set<Id>();

        for (Contact c : allContacts) {
            contactById.put(c.Id, c);
            contactIds.add(c.Id);
        }

        for (Contact c : allContacts) {
            // Treat as root if ReportsToId is null OR points outside this account
            Id parentId = (c.ReportsToId != null && contactIds.contains(c.ReportsToId))
                ? c.ReportsToId
                : null;

            if (parentId != null) {
                if (!childrenByParent.containsKey(parentId)) {
                    childrenByParent.put(parentId, new List<Contact>());
                }
                childrenByParent.get(parentId).add(c);
            }
        }

        // Identify root contacts (no in-account parent)
        List<Contact> roots = new List<Contact>();
        for (Contact c : allContacts) {
            Id parentId = (c.ReportsToId != null && contactIds.contains(c.ReportsToId))
                ? c.ReportsToId
                : null;
            if (parentId == null) {
                roots.add(c);
            }
        }

        // BFS traversal capped at MAX_DEPTH
        List<ContactNode> resultNodes = new List<ContactNode>();
        List<Id>          bfsQueue    = new List<Id>();
        Map<Id, Integer>  depthMap    = new Map<Id, Integer>();
        Set<Id>           visited     = new Set<Id>();

        for (Contact root : roots) {
            bfsQueue.add(root.Id);
            depthMap.put(root.Id, 0);
        }

        Integer idx = 0;
        while (idx < bfsQueue.size()) {
            Id currentId = bfsQueue.get(idx);
            idx++;

            if (visited.contains(currentId)) {
                continue;
            }
            visited.add(currentId);

            Contact c     = contactById.get(currentId);
            Integer depth = depthMap.get(currentId);

            ContactNode node = new ContactNode();
            node.id       = c.Id;
            node.name     = c.Name;
            node.title    = c.Title;
            node.email    = canReadEmail     ? c.Email         : null;
            node.photoUrl = canReadPhotoUrl  ? c.PhotoUrl       : null;
            node.parentId = (c.ReportsToId != null && contactIds.contains(c.ReportsToId))
                            ? c.ReportsToId : null;
            node.depth    = depth;
            node.isRoot   = (node.parentId == null);
            node.languages = canReadLanguages ? c.Languages__c   : null;
            node.level    = canReadLevel     ? c.Level__c       : null;
            resultNodes.add(node);

            if (depth < MAX_DEPTH && childrenByParent.containsKey(currentId)) {
                for (Contact child : childrenByParent.get(currentId)) {
                    if (!visited.contains(child.Id)) {
                        bfsQueue.add(child.Id);
                        depthMap.put(child.Id, depth + 1);
                    }
                }
            }
        }

        return new OrgChartResponse(resultNodes, isTruncated);
    }

    // ─────────────────────────────────────────────────────────────────
    // Inner classes
    // ─────────────────────────────────────────────────────────────────

    /**
     * @description Wrapper returned to LWC containing the flat node list
     *              and a truncation flag.
     */
    public class OrgChartResponse {
        /** Flat list of ContactNode records. */
        @AuraEnabled public List<ContactNode> nodes;
        /** True when the raw query hit the 2000-record LIMIT. */
        @AuraEnabled public Boolean           isTruncated;

        /** @description Constructor. */
        public OrgChartResponse(List<ContactNode> nodes, Boolean isTruncated) {
            this.nodes       = nodes;
            this.isTruncated = isTruncated;
        }
    }

    /**
     * @description Represents a single Contact in the hierarchy tree.
     */
    public class ContactNode {
        /** Salesforce Contact Id. */
        @AuraEnabled public Id      id;
        /** Contact full name. */
        @AuraEnabled public String  name;
        /** Job title. */
        @AuraEnabled public String  title;
        /** Email address (FLS-gated). */
        @AuraEnabled public String  email;
        /** Profile photo URL (FLS-gated). */
        @AuraEnabled public String  photoUrl;
        /** Id of the parent Contact (null for root nodes). */
        @AuraEnabled public Id      parentId;
        /** Zero-based depth in the hierarchy (0 = root). */
        @AuraEnabled public Integer depth;
        /** True when the node has no in-account parent. */
        @AuraEnabled public Boolean isRoot;
        /** Languages picklist value (FLS-gated). */
        @AuraEnabled public String  languages;
        /** Level picklist value (FLS-gated). */
        @AuraEnabled public String  level;
    }
}