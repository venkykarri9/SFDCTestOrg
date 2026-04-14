trigger DealProductTrigger on Deal_Product__c (after insert, after update, after delete) {
    Set<Id> dealIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Deal_Product__c dp : Trigger.new) {
            dealIds.add(dp.Deal__c);
        }
    }
    if (Trigger.isDelete) {
        for (Deal_Product__c dp : Trigger.old) {
            dealIds.add(dp.Deal__c);
        }
    }

    // Rollup total price to Deal
    if (!dealIds.isEmpty()) {
        List<Deal__c> dealsToUpdate = new List<Deal__c>();
        for (AggregateResult ar : [SELECT Deal__c, SUM(Total_Price__c) totalValue
                                   FROM Deal_Product__c
                                   WHERE Deal__c IN :dealIds
                                   GROUP BY Deal__c]) {
            dealsToUpdate.add(new Deal__c(
                Id = (Id)ar.get('Deal__c'),
                Deal_Value__c = (Decimal)ar.get('totalValue')
            ));
        }
        // Handle deals with no products remaining
        Set<Id> dealsWithProducts = new Set<Id>();
        for (Deal__c d : dealsToUpdate) { dealsWithProducts.add(d.Id); }
        for (Id dealId : dealIds) {
            if (!dealsWithProducts.contains(dealId)) {
                dealsToUpdate.add(new Deal__c(Id = dealId, Deal_Value__c = 0));
            }
        }
        if (!dealsToUpdate.isEmpty()) update dealsToUpdate;
    }
}
