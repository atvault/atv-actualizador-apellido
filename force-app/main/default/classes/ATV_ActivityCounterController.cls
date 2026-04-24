/**
 * @description: Controller for ATV_ActivityCounterPage Visualforce page
 * @author: AT Vault
 */
public with sharing class ATV_ActivityCounterController {
    
    /**
     * @description: Constructor
     */
    public ATV_ActivityCounterController() {
        // Empty constructor
    }
    
    /**
     * @description: Method to run the event counter batch
     * @return PageReference - null to stay on the same page
     */
    public PageReference runEventCounter() {
        try {
            ATV_ActivityCounterBatch eventBatch = new ATV_ActivityCounterBatch('Event');
            Database.executeBatch(eventBatch, 200);
            
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.INFO,
                'Event counter batch has been queued. You will receive an email notification when the process is complete.'
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'An error occurred: ' + e.getMessage()
            ));
        }
        
        return null;
    }
    
    /**
     * @description: Method to run the task counter batch
     * @return PageReference - null to stay on the same page
     */
    public PageReference runTaskCounter() {
        try {
            ATV_ActivityCounterBatch taskBatch = new ATV_ActivityCounterBatch('Task');
            Database.executeBatch(taskBatch, 200);
            
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.INFO,
                'Task counter batch has been queued. You will receive an email notification when the process is complete.'
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'An error occurred: ' + e.getMessage()
            ));
        }
        
        return null;
    }
    
    /**
     * @description: Method to run both event and task counter batches
     * @return PageReference - null to stay on the same page
     */
    public PageReference runFullCounter() {
        try {
            ATV_ActivityCounterBatch.runFullUpdate();
            
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.INFO,
                'Full activity counter batch has been queued. You will receive an email notification when each process is complete.'
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'An error occurred: ' + e.getMessage()
            ));
        }
        
        return null;
    }
}