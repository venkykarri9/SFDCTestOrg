public with sharing class IndustryPicklistController {

    /**
     * @description Returns a list of picklist option maps filtered by industry and field API name.
     * @param industry     The Account.Industry value (e.g. 'Technology').
     * @param fieldApiName The API name of the field being filtered (e.g. 'Sub_Industry__c').
     * @return             List of { label, value } maps for the lightning-combobox.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistOptions(
            String industry,
            String fieldApiName) {

        List<Map<String, String>> options = new List<Map<String, String>>();

        if (String.isBlank(industry) || String.isBlank(fieldApiName)) {
            return options;
        }

        List<Industry_Picklist_Config__mdt> configs = [
            SELECT Allowed_Values__c
            FROM   Industry_Picklist_Config__mdt
            WHERE  Industry__c      = :industry
            AND    Field_API_Name__c = :fieldApiName
            AND    Is_Active__c      = true
            LIMIT  1
        ];

        if (configs.isEmpty() || String.isBlank(configs[0].Allowed_Values__c)) {
            return options;
        }

        String[] tokens = configs[0].Allowed_Values__c.split(';');
        for (String token : tokens) {
            String trimmed = token.trim();
            if (String.isNotBlank(trimmed)) {
                Map<String, String> opt = new Map<String, String>();
                opt.put('label', trimmed);
                opt.put('value', trimmed);
                options.add(opt);
            }
        }

        return options;
    }
}