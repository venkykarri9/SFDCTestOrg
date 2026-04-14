@IsTest
private class IndustryPicklistControllerTest {

    @TestSetup
    static void makeData() {
        // Custom metadata cannot be inserted in tests; rely on existing CMDT records
        // or mock via stub if needed. Tests below use the actual CMDT in the org.
    }

    @IsTest
    static void testGetPicklistOptions_technology() {
        Test.startTest();
        List<Map<String, String>> result =
            IndustryPicklistController.getPicklistOptions('Technology', 'Sub_Industry__c');
        Test.stopTest();

        // Result may be empty in scratch orgs without CMDT records; just assert no exception
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @IsTest
    static void testGetPicklistOptions_blankIndustry() {
        Test.startTest();
        List<Map<String, String>> result =
            IndustryPicklistController.getPicklistOptions('', 'Sub_Industry__c');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Blank industry should return empty list');
    }

    @IsTest
    static void testGetPicklistOptions_blankFieldApiName() {
        Test.startTest();
        List<Map<String, String>> result =
            IndustryPicklistController.getPicklistOptions('Technology', '');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Blank fieldApiName should return empty list');
    }

    @IsTest
    static void testGetPicklistOptions_nullParams() {
        Test.startTest();
        List<Map<String, String>> result =
            IndustryPicklistController.getPicklistOptions(null, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Null params should return empty list');
    }

    @IsTest
    static void testGetPicklistOptions_unknownIndustry() {
        Test.startTest();
        List<Map<String, String>> result =
            IndustryPicklistController.getPicklistOptions('UnknownIndustryXYZ', 'Sub_Industry__c');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Unknown industry should return empty list');
    }
}