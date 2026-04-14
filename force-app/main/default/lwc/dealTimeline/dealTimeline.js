import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class DealTimeline extends NavigationMixin(LightningElement) {
    @api recordId;
    activities = [];
    filteredActivities = [];
    isLoading = true;
    error;
    activeFilter = 'All';

    get computedFilters() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Calls', value: 'Call' },
            { label: 'Emails', value: 'Email' },
            { label: 'Meetings', value: 'Meeting' }
        ].map(f => ({
            ...f,
            variant: f.value === this.activeFilter ? 'brand' : 'neutral'
        }));
    }

    connectedCallback() {
        this.loadActivities();
    }

    async loadActivities() {
        try {
            this.isLoading = true;
            // In real impl, would use @wire with getRelatedListRecords
            // For now, using imperative approach placeholder
            this.activities = [];
            this.applyFilter();
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    handleFilterChange(event) {
        this.activeFilter = event.target.value;
        this.applyFilter();
    }

    applyFilter() {
        if (this.activeFilter === 'All') {
            this.filteredActivities = [...this.activities];
        } else {
            this.filteredActivities = this.activities.filter(
                a => a.Activity_Type__c === this.activeFilter
            );
        }
    }

    get hasActivities() {
        return this.filteredActivities.length > 0;
    }

    getActivityIcon(type) {
        const icons = {
            Call: 'standard:log_a_call',
            Email: 'standard:email',
            Meeting: 'standard:event',
            Demo: 'standard:screen',
            'Proposal Sent': 'standard:document',
            'Follow-up': 'standard:task'
        };
        return icons[type] || 'standard:task';
    }

    handleAddActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Deal_Activity__c',
                actionName: 'new'
            }
        });
    }
}
