/**
 * @description: Batch class to count all existing events and tasks for accounts
 * @author: AT Vault
 */
public class ATV_ActivityCounterBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private Integer totalEventsProcessed = 0;
    private Integer totalTasksProcessed = 0;
    private Integer totalAccountsUpdated = 0;
    private Set<Id> processedAccountIds = new Set<Id>();
    private String batchType;
    
    /**
     * @description Constructor to specify which type of batch to run
     * @param type - 'Event', 'Task', or 'Both'
     */
    public ATV_ActivityCounterBatch(String type) {
        this.batchType = type;
    }
    
    /**
     * @description Start method that retrieves the records to process
     * @param bc - BatchableContext
     * @return Database.QueryLocator - the records to process
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query;
        
        if (batchType == 'Event') {
            query = 'SELECT Id, WhatId, ActivityDate, ActivityDateTime FROM Event ' +
                   'WHERE WhatId != null AND What.Type = \'Account\'';
        } 
        else if (batchType == 'Task') {
            query = 'SELECT Id, WhatId, ActivityDate, TaskSubtype, Subject FROM Task ' +
                   'WHERE WhatId != null AND What.Type = \'Account\' ' +
                   'AND TaskSubtype = \'Call\' AND Subject LIKE \'R -%\'';
        }
        else {
            // Default to all events
            query = 'SELECT Id, WhatId, ActivityDate, ActivityDateTime FROM Event ' +
                   'WHERE WhatId != null AND What.Type = \'Account\'';
        }
        
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Execute method that processes each batch of records
     * @param bc - BatchableContext
     * @param scope - List of records to process
     */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        if (scope.isEmpty()) return;
        
        Set<Id> accountIds = new Set<Id>();
        
        for (sObject record : scope) {
            Id whatId = (Id)record.get('WhatId');
            if (whatId != null) {
                accountIds.add(whatId);
            }
            
            if (batchType == 'Event') {
                totalEventsProcessed++;
            } else if (batchType == 'Task') {
                totalTasksProcessed++;
            }
        }
        
        if (!accountIds.isEmpty()) {
            processedAccountIds.addAll(accountIds);
            
            if (batchType == 'Event') {
                ATV_AccountHelper.updateAccountMeetingCounts(accountIds);
            } else if (batchType == 'Task') {
                ATV_AccountHelper.updateAccountCallCounts(accountIds);
            } else if (batchType == 'Both') {
                ATV_AccountHelper.updateAccountCallAndMeetingCounts(accountIds);
            }
            
            totalAccountsUpdated += accountIds.size();
        }
    }
    
    /**
     * @description Finish method that executes after all batches are processed
     * @param bc - BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        // Send email notification with results
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        // Get the executing user's email
        User currentUser = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()];
        String[] toAddresses = new String[] {currentUser.Email};
        mail.setToAddresses(toAddresses);
        
        mail.setSubject('ATV Activity Counter Batch Completed');
        
        String body = 'The ATV Activity Counter Batch has completed processing.\n\n';
        body += 'Batch Type: ' + batchType + '\n';
        body += 'Total Events Processed: ' + totalEventsProcessed + '\n';
        body += 'Total Tasks Processed: ' + totalTasksProcessed + '\n';
        body += 'Total Unique Accounts Updated: ' + processedAccountIds.size() + '\n';
        body += 'Total Account Updates Performed: ' + totalAccountsUpdated + '\n';
        
        mail.setPlainTextBody(body);
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
    
    /**
     * @description Static method to execute the batch for both events and tasks
     */
    public static void runFullUpdate() {
        // First process all events
        ATV_ActivityCounterBatch eventBatch = new ATV_ActivityCounterBatch('Event');
        Database.executeBatch(eventBatch, 100);
        
        // Then process all tasks
        ATV_ActivityCounterBatch taskBatch = new ATV_ActivityCounterBatch('Task');
        Database.executeBatch(taskBatch, 100);
    }
}