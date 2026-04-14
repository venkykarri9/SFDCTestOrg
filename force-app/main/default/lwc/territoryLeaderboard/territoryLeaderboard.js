import { LightningElement } from 'lwc';
import getTopPerformers from '@salesforce/apex/TerritoryService.getTopPerformers';

export default class TerritoryLeaderboard extends LightningElement {
    territories = [];
    isLoading = true;
    error;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        try {
            this.isLoading = true;
            const data = await getTopPerformers({ limitCount: 20 });
            this.territories = data.map((t, index) => ({
                ...t,
                rank: index + 1,
                attainment: t.Quota_Attainment__c || 0,
                formattedTarget: this.formatCurrency(t.Annual_Target__c),
                formattedActual: this.formatCurrency(t.Actual_Amount__c),
                progressVariant: t.Quota_Attainment__c >= 100
                    ? 'success'
                    : t.Quota_Attainment__c >= 75
                        ? 'warning'
                        : 'expired',
                cssClass: t.Quota_Attainment__c >= 100
                    ? 'slds-text-color_success'
                    : t.Quota_Attainment__c >= 75
                        ? ''
                        : 'slds-text-color_error'
            }));
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value || 0);
    }

    get hasData() {
        return this.territories.length > 0;
    }
}
