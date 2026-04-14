public with sharing class AccountTriggerHandler {

    private final AccountDuplicateNameHandler duplicateHandler;

    public AccountTriggerHandler() {
        this.duplicateHandler = new AccountDuplicateNameHandler();
    }

    public void onBeforeInsert(List<Account> newAccounts) {
        duplicateHandler.handleBeforeInsert(newAccounts);
    }

    public void onBeforeUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        duplicateHandler.handleBeforeUpdate(newAccounts, oldMap);
    }
}