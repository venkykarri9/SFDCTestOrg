public with sharing class AccountDuplicateNameHandler {

    @TestVisible
    private static final String DUPLICATE_NAME_ERROR = 'An Account with this name already exists.';

    public void handleBeforeInsert(List<Account> newAccounts) {
        if (newAccounts == null || newAccounts.isEmpty()) return;

        Set<String> lowerNames = buildLowerNameSet(newAccounts);
        if (lowerNames.isEmpty()) return;

        Set<String> existingLowerNames = queryExistingNames(lowerNames);
        applyErrors(newAccounts, existingLowerNames);
    }

    public void handleBeforeUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        if (newAccounts == null || newAccounts.isEmpty()) return;

        List<Account> nameChanged = new List<Account>();
        for (Account acc : newAccounts) {
            Account old = oldMap.get(acc.Id);
            if (String.isBlank(acc.Name)) continue;
            if (old != null && acc.Name.equalsIgnoreCase(old.Name)) continue;
            nameChanged.add(acc);
        }

        if (nameChanged.isEmpty()) return;

        Set<String> lowerNames = buildLowerNameSet(nameChanged);
        if (lowerNames.isEmpty()) return;

        Set<String> existingLowerNames = queryExistingNames(lowerNames);
        applyErrors(nameChanged, existingLowerNames);
    }

    @TestVisible
    private Set<String> buildLowerNameSet(List<Account> accounts) {
        Set<String> seen = new Set<String>();
        for (Account acc : accounts) {
            if (String.isBlank(acc.Name)) continue;
            String lowerName = acc.Name.toLowerCase();
            if (seen.contains(lowerName)) {
                acc.Name.addError(DUPLICATE_NAME_ERROR);
            } else {
                seen.add(lowerName);
            }
        }
        return seen;
    }

    @TestVisible
    private Set<String> queryExistingNames(Set<String> lowerNames) {
        Set<String> existingLower = new Set<String>();
        if (lowerNames == null || lowerNames.isEmpty()) return existingLower;

        List<Account> existingAccounts = [
            SELECT Id, Name
            FROM Account
            WHERE Name IN :lowerNames
            WITH SECURITY_ENFORCED
        ];
        for (Account acc : existingAccounts) {
            if (String.isNotBlank(acc.Name)) existingLower.add(acc.Name.toLowerCase());
        }

        for (String lowerName : lowerNames) {
            List<Account> likeAccounts = [
                SELECT Id, Name
                FROM Account
                WHERE Name LIKE :lowerName
                WITH SECURITY_ENFORCED
            ];
            for (Account acc : likeAccounts) {
                if (String.isNotBlank(acc.Name)) existingLower.add(acc.Name.toLowerCase());
            }
        }

        return existingLower;
    }

    @TestVisible
    private void applyErrors(List<Account> accounts, Set<String> existingLowerNames) {
        if (existingLowerNames == null || existingLowerNames.isEmpty()) return;
        for (Account acc : accounts) {
            if (String.isBlank(acc.Name)) continue;
            if (existingLowerNames.contains(acc.Name.toLowerCase())) {
                acc.Name.addError(DUPLICATE_NAME_ERROR);
            }
        }
    }
}