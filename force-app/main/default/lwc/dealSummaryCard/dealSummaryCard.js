import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRecentDeals from '@salesforce/apex/DealService.getRecentDeals';

export default class DealSummaryCard extends NavigationMixin(LightningElement) {
    @api recordId;

    summary = { totalDeals: 0, totalValue: 0, weightedValue: 0, closedWon: 0 };
    isLoading = true;
    error;

    connectedCallback() {
        this.loadSummary();
    }

    async loadSummary() {
        try {
            this.isLoading = true;
            const deals = await getRecentDeals({ limitCount: 200 });
            this.summary = this.computeSummary(deals);
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    computeSummary(deals) {
        const summary = { totalDeals: deals.length, totalValue: 0, weightedValue: 0, closedWon: 0 };
        deals.forEach(deal => {
            if (deal.Deal_Value__c) {
                summary.totalValue += deal.Deal_Value__c;
                summary.weightedValue += deal.Deal_Value__c * ((deal.Win_Probability__c || 0) / 100);
            }
            if (deal.Deal_Stage__c === 'Closed Won') summary.closedWon++;
        });
        return summary;
    }

    get formattedTotalValue() {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })
            .format(this.summary.totalValue);
    }

    get formattedWeightedValue() {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })
            .format(this.summary.weightedValue);
    }

    get hasDeals() {
        return this.summary.totalDeals > 0;
    }

    handleViewAllDeals() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Deal__c', actionName: 'list' }
        });
    }
}
