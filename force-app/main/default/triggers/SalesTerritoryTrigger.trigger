trigger SalesTerritoryTrigger on Sales_Territory__c (before insert, before update, after update) {
    if (Trigger.isBefore) {
        for (Sales_Territory__c territory : Trigger.new) {
            // Active territories must have a manager
            if (Trigger.isInsert && territory.Active__c && territory.Territory_Manager__c == null) {
                territory.addError('Active territories must have a Territory Manager assigned');
            }
            // Cannot deactivate territory with open deals
            if (Trigger.isUpdate) {
                Sales_Territory__c oldTerr = Trigger.oldMap.get(territory.Id);
                if (oldTerr.Active__c && !territory.Active__c) {
                    Integer openDeals = [SELECT COUNT() FROM Deal__c
                                        WHERE Territory__c = :territory.Id
                                        AND Deal_Stage__c NOT IN ('Closed Won', 'Closed Lost')];
                    if (openDeals > 0) {
                        territory.addError('Cannot deactivate territory with ' + openDeals + ' open deals');
                    }
                }
            }
        }
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        for (Sales_Territory__c territory : Trigger.new) {
            Sales_Territory__c oldTerr = Trigger.oldMap.get(territory.Id);
            if (territory.Territory_Manager__c != oldTerr.Territory_Manager__c) {
                System.debug('Territory manager changed for: ' + territory.Name);
            }
        }
    }
}
