trigger SalesForecastTrigger on Sales_Forecast__c (before insert, before update) {
    for (Sales_Forecast__c forecast : Trigger.new) {
        // Validate target amount
        if (forecast.Target_Amount__c != null && forecast.Target_Amount__c <= 0) {
            forecast.Target_Amount__c.addError('Target Amount must be greater than zero');
        }

        if (Trigger.isInsert) {
            // Validate month not in the past
            if (forecast.Forecast_Month__c != null && forecast.Forecast_Month__c < Date.today().toStartOfMonth()) {
                forecast.Forecast_Month__c.addError('Forecast month cannot be in the past');
            }
            // Default status
            if (forecast.Status__c == null) {
                forecast.Status__c = 'Draft';
            }
        }

        if (Trigger.isUpdate) {
            Sales_Forecast__c oldForecast = Trigger.oldMap.get(forecast.Id);
            // Prevent edits to approved forecasts
            if (oldForecast.Status__c == 'Approved') {
                if (forecast.Target_Amount__c != oldForecast.Target_Amount__c ||
                    forecast.Committed_Amount__c != oldForecast.Committed_Amount__c ||
                    forecast.Best_Case_Amount__c != oldForecast.Best_Case_Amount__c) {
                    forecast.addError('Cannot modify amounts on an approved forecast');
                }
            }
        }
    }
}
