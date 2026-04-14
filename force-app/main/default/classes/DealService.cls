public with sharing class DealService {

    public class DealSummary {
        public Integer totalDeals;
        public Decimal totalValue;
        public Decimal weightedValue;
        public Integer closedWon;
        public Integer closedLost;

        public DealSummary() {
            totalDeals = 0;
            totalValue = 0;
            weightedValue = 0;
            closedWon = 0;
            closedLost = 0;
        }
    }

    public static DealSummary getDealSummary(Id accountId) {
        DealSummary summary = new DealSummary();

        List<Deal__c> deals = [
            SELECT Id, Deal_Value__c, Win_Probability__c, Deal_Stage__c
            FROM Deal__c
            WHERE Account__c = :accountId
        ];

        summary.totalDeals = deals.size();

        for (Deal__c deal : deals) {
            if (deal.Deal_Value__c != null) {
                summary.totalValue += deal.Deal_Value__c;
                summary.weightedValue += deal.Deal_Value__c *
                    (deal.Win_Probability__c != null ? deal.Win_Probability__c / 100 : 0);
            }
            if (deal.Deal_Stage__c == 'Closed Won') summary.closedWon++;
            if (deal.Deal_Stage__c == 'Closed Lost') summary.closedLost++;
        }

        return summary;
    }

    @AuraEnabled(cacheable=true)
    public static List<Deal__c> getRecentDeals(Integer limitCount) {
        return [
            SELECT Id, Name, Deal_Stage__c, Deal_Value__c,
                   Close_Date__c, Win_Probability__c, Account__c
            FROM Deal__c
            ORDER BY CreatedDate DESC
            LIMIT :limitCount
        ];
    }

    @AuraEnabled
    public static String updateDealStage(Id dealId, String newStage) {
        try {
            Deal__c deal = [SELECT Id, Deal_Stage__c FROM Deal__c WHERE Id = :dealId];
            deal.Deal_Stage__c = newStage;
            update deal;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Deal__c> getDealsByTerritory(Id territoryId) {
        return [
            SELECT Id, Name, Deal_Stage__c, Deal_Value__c, Close_Date__c,
                   Win_Probability__c, Account__c, Account__r.Name, Territory__c
            FROM Deal__c
            WHERE Territory__c = :territoryId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWinLossAnalysis(Integer months) {
        Date startDate = Date.today().addMonths(-months);
        List<Deal__c> closedDeals = [
            SELECT Id, Deal_Stage__c, Deal_Value__c, Close_Date__c
            FROM Deal__c
            WHERE Deal_Stage__c IN ('Closed Won', 'Closed Lost')
            AND Close_Date__c >= :startDate
        ];

        Integer wonCount = 0;
        Integer lostCount = 0;
        Decimal totalWonValue = 0;

        for (Deal__c deal : closedDeals) {
            if (deal.Deal_Stage__c == 'Closed Won') {
                wonCount++;
                if (deal.Deal_Value__c != null) totalWonValue += deal.Deal_Value__c;
            } else {
                lostCount++;
            }
        }

        Decimal winRate = (wonCount + lostCount) > 0
            ? ((Decimal)wonCount / (wonCount + lostCount) * 100).setScale(2) : 0;
        Decimal avgDealSize = wonCount > 0
            ? (totalWonValue / wonCount).setScale(2) : 0;

        Map<String, Object> result = new Map<String, Object>();
        result.put('wonCount', wonCount);
        result.put('lostCount', lostCount);
        result.put('winRate', winRate);
        result.put('avgDealSize', avgDealSize);
        return result;
    }
}
