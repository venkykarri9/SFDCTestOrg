import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRecentDeals from '@salesforce/apex/DealService.getRecentDeals';

export default class DealKanbanBoard extends NavigationMixin(LightningElement) {
    deals = [];
    isLoading = true;
    error;

    stages = ['Prospecting', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won', 'Closed Lost'];

    connectedCallback() {
        this.loadDeals();
    }

    async loadDeals() {
        try {
            this.isLoading = true;
            this.deals = await getRecentDeals({ limitCount: 100 });
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    get columns() {
        return this.stages.map(stage => ({
            stage,
            deals: this.deals.filter(d => d.Deal_Stage__c === stage),
            count: this.deals.filter(d => d.Deal_Stage__c === stage).length,
            key: stage.replace(/\s/g, '_')
        }));
    }

    get hasDeals() {
        return this.deals.length > 0;
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value || 0);
    }

    handleDealClick(event) {
        const dealId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: dealId,
                objectApiName: 'Deal__c',
                actionName: 'view'
            }
        });
    }

    handleDragStart(event) {
        event.dataTransfer.setData('text/plain', event.currentTarget.dataset.id);
    }

    handleDragOver(event) {
        event.preventDefault();
    }

    async handleDrop(event) {
        event.preventDefault();
        const dealId = event.dataTransfer.getData('text/plain');
        const newStage = event.currentTarget.dataset.stage;
        // Would call updateDealStage here
        await this.loadDeals();
    }
}
