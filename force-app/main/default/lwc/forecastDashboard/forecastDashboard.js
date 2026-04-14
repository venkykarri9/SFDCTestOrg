import { LightningElement } from 'lwc';
import getCurrentForecast from '@salesforce/apex/ForecastService.getCurrentForecast';
import submitForecast from '@salesforce/apex/ForecastService.submitForecast';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ForecastDashboard extends LightningElement {
    forecasts = [];
    isLoading = true;
    error;

    connectedCallback() {
        this.loadForecasts();
    }

    async loadForecasts() {
        try {
            this.isLoading = true;
            // Would load forecasts for all territories
            this.forecasts = [];
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    get totalTarget() {
        return this.forecasts.reduce((sum, f) => sum + (f.Target_Amount__c || 0), 0);
    }

    get totalCommitted() {
        return this.forecasts.reduce((sum, f) => sum + (f.Committed_Amount__c || 0), 0);
    }

    get totalBestCase() {
        return this.forecasts.reduce((sum, f) => sum + (f.Best_Case_Amount__c || 0), 0);
    }

    get totalActual() {
        return this.forecasts.reduce((sum, f) => sum + (f.Actual_Amount__c || 0), 0);
    }

    get hasForecasts() {
        return this.forecasts.length > 0;
    }

    get formattedTarget() {
        return this.formatCurrency(this.totalTarget);
    }

    get formattedCommitted() {
        return this.formatCurrency(this.totalCommitted);
    }

    get formattedBestCase() {
        return this.formatCurrency(this.totalBestCase);
    }

    get formattedActual() {
        return this.formatCurrency(this.totalActual);
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value);
    }

    async handleSubmit(event) {
        const forecastId = event.target.dataset.id;
        try {
            await submitForecast({ forecastId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Forecast submitted',
                    variant: 'success'
                })
            );
            await this.loadForecasts();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        }
    }
}
