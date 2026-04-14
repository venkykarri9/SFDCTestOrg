/**
 * @description Service class responsible for threading inbound Email-to-Case and Web-to-Case
 * records to existing parent Cases when the Subject contains a [Ref:XXXXXXXX] token.
 *
 * Threading rules:
 * - Subject is parsed for the first occurrence of [Ref:XXXXXXXX] (8-digit, zero-padded CaseNumber).
 * - If the referenced CaseNumber resolves to an existing Case visible to the running user,
 *   the new Case's ParentId is set to that Case's Id.
 * - Is_Threaded__c is set to true only when this service assigns ParentId in the current transaction.
 * - If ParentId is already populated before the trigger fires, it is NOT overwritten.
 * - Unresolvable references (non-existent or inaccessible due to sharing) are silently skipped.
 * - A single SOQL query is issued per trigger invocation regardless of batch size.
 */
public with sharing class CaseThreadingService {

    /** Matches the first [Ref:XXXXXXXX] token — exactly 8 numeric digits, zero-padded. */
    @TestVisible
    private static final Pattern REF_PATTERN = Pattern.compile('\\[Ref:(\\d{8})\\]');

    /**
     * @description Entry point called from CaseTrigger before insert.
     * Parses subjects, resolves parent Case IDs in a single SOQL query, and sets
     * ParentId and Is_Threaded__c on qualifying Case records.
     *
     * @param newCases List of Case records from Trigger.new (before insert context).
     */
    public static void threadCases(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }

        // Step 1: Extract all reference numbers from subjects.
        Map<Integer, String> caseIndexToRefNumber = buildIndexToRefMap(newCases);

        if (caseIndexToRefNumber.isEmpty()) {
            return;
        }

        // Step 2: Collect unique reference numbers for SOQL.
        Set<String> refNumbers = new Set<String>(caseIndexToRefNumber.values());

        // Step 3: Resolve CaseNumbers to Ids — single SOQL for entire batch.
        Map<String, Id> caseNumberToId = resolveParentIds(refNumbers);

        if (caseNumberToId.isEmpty()) {
            return;
        }

        // Step 4: Apply ParentId and Is_Threaded__c to qualifying cases.
        for (Integer i = 0; i < newCases.size(); i++) {
            Case c = newCases[i];

            // Do not overwrite a ParentId already set before trigger fires.
            if (c.ParentId != null) {
                continue;
            }

            String refNum = caseIndexToRefNumber.get(i);
            if (refNum == null) {
                continue;
            }

            Id parentId = caseNumberToId.get(refNum);
            if (parentId != null) {
                c.ParentId = parentId;
                c.Is_Threaded__c = true;
            }
        }
    }

    /**
     * @description Builds a map from the list index (Integer) of each Case to the
     * first reference number found in its Subject. Cases without a matching Subject
     * are excluded from the map.
     *
     * @param newCases List of Case records to inspect.
     * @return Map of list index to extracted 8-digit CaseNumber string.
     */
    @TestVisible
    private static Map<Integer, String> buildIndexToRefMap(List<Case> newCases) {
        Map<Integer, String> result = new Map<Integer, String>();
        for (Integer i = 0; i < newCases.size(); i++) {
            Case c = newCases[i];
            if (String.isBlank(c.Subject)) {
                continue;
            }
            Matcher m = REF_PATTERN.matcher(c.Subject);
            if (m.find()) {
                // Group 1 captures the 8-digit number inside [Ref:XXXXXXXX].
                result.put(i, m.group(1));
            }
        }
        return result;
    }

    /**
     * @description Extracts the set of reference CaseNumber strings from a list of Cases.
     * Provided as a public utility method per the design blueprint.
     *
     * @param newCases List of Case records to inspect.
     * @return Set of extracted 8-digit CaseNumber strings (deduplicated).
     */
    public static Set<String> extractRefNumbers(List<Case> newCases) {
        Set<String> refNumbers = new Set<String>();
        if (newCases == null) {
            return refNumbers;
        }
        for (Case c : newCases) {
            if (String.isBlank(c.Subject)) {
                continue;
            }
            Matcher m = REF_PATTERN.matcher(c.Subject);
            if (m.find()) {
                refNumbers.add(m.group(1));
            }
        }
        return refNumbers;
    }

    /**
     * @description Queries Case records whose CaseNumber matches one of the supplied
     * reference numbers. With sharing is enforced — inaccessible Cases are silently
     * excluded, which is equivalent to a non-existent reference.
     *
     * Executes a single SOQL query regardless of the set size.
     *
     * @param caseNumbers Set of 8-digit CaseNumber strings to look up.
     * @return Map of CaseNumber string to Case Id for all resolved records.
     */
    public static Map<String, Id> resolveParentIds(Set<String> caseNumbers) {
        Map<String, Id> result = new Map<String, Id>();
        if (caseNumbers == null || caseNumbers.isEmpty()) {
            return result;
        }
        for (Case c : [
            SELECT Id, CaseNumber
            FROM Case
            WHERE CaseNumber IN :caseNumbers
        ]) {
            result.put(c.CaseNumber, c.Id);
        }
        return result;
    }
}