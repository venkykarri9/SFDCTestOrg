public with sharing class DealCloneService {

    @AuraEnabled
    public static Id cloneDeal(Id dealId) {
        Deal__c original = [SELECT Id, Account__c, Primary_Contact__c, Deal_Value__c,
                                   Deal_Source__c, Is_Strategic__c, Territory__c, Campaign__c,
                                   Competitor__c, Next_Step__c
                            FROM Deal__c WHERE Id = :dealId];

        Deal__c cloned = original.clone(false, true, false, false);
        cloned.Deal_Stage__c = 'Prospecting';
        cloned.Win_Probability__c = 10;
        cloned.Close_Date__c = Date.today().addDays(30);
        insert cloned;

        // Clone Deal Products
        List<Deal_Product__c> originalProducts = [SELECT Product__c, Quantity__c, Unit_Price__c, Discount__c, Product_Family__c
                FROM Deal_Product__c WHERE Deal__c = :dealId];
        List<Deal_Product__c> clonedProducts = new List<Deal_Product__c>();
        for (Deal_Product__c prod : originalProducts) {
            Deal_Product__c clonedProd = prod.clone(false, true, false, false);
            clonedProd.Deal__c = cloned.Id;
            clonedProducts.add(clonedProd);
        }
        if (!clonedProducts.isEmpty()) insert clonedProducts;

        return cloned.Id;
    }

    @AuraEnabled
    public static String mergeDuplicateDeals(Id primaryId, Id duplicateId) {
        try {
            // Move activities to primary
            List<Deal_Activity__c> activities = [SELECT Id FROM Deal_Activity__c WHERE Deal__c = :duplicateId];
            for (Deal_Activity__c a : activities) { a.Deal__c = primaryId; }
            if (!activities.isEmpty()) update activities;

            // Move competitors to primary
            List<Deal_Competitor__c> competitors = [SELECT Id FROM Deal_Competitor__c WHERE Deal__c = :duplicateId];
            for (Deal_Competitor__c c : competitors) { c.Deal__c = primaryId; }
            if (!competitors.isEmpty()) update competitors;

            // Close duplicate
            Deal__c duplicate = [SELECT Id FROM Deal__c WHERE Id = :duplicateId];
            duplicate.Deal_Stage__c = 'Closed Lost';
            duplicate.Next_Step__c = 'Merged into deal ' + primaryId;
            update duplicate;

            return 'Deals merged successfully';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
