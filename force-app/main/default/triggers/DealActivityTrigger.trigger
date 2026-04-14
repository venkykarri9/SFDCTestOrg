trigger DealActivityTrigger on Deal_Activity__c (before insert, before update, after insert) {
    if (Trigger.isBefore) {
        for (Deal_Activity__c activity : Trigger.new) {
            if (activity.Activity_Date__c == null) {
                activity.Activity_Date__c = DateTime.now();
            }
            // Validate notes required for meetings
            if (activity.Activity_Type__c == 'Meeting' && String.isBlank(activity.Notes__c)) {
                activity.Notes__c.addError('Notes are required for Meeting activities');
            }
        }
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        // Log activity creation
        for (Deal_Activity__c activity : Trigger.new) {
            System.debug('New activity created for deal: ' + activity.Deal__c);
        }
    }
}
