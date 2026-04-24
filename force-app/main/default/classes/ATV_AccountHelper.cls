/**
 * @description: Account helper class with ATV_ prefix for AT Vault implementations
 * @author: AT Vault
 */
public class ATV_AccountHelper {
    
    /**
     * @description: Updates the meeting counts for accounts
     * @param accountIds - Set of Account IDs to update
     */
    public static void updateAccountMeetingCounts(Set<Id> accountIds) {
        if(accountIds == null || accountIds.isEmpty()) return;
        
        // Get all accounts with their creation date and conversion date
        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();
        for(Account acc : [SELECT Id, CreatedDate, Fecha_Conversi_n_MKT__c, ATV_Total_Reuniones__c 
                           FROM Account 
                           WHERE Id IN :accountIds]) {
            accountsToUpdate.put(acc.Id, acc);
        }
        
        // Query all events for these accounts
        Map<Id, Integer> accountMeetingCounts = new Map<Id, Integer>();
        
        // Initialize count to 0 for all accounts
        for(Id accId : accountsToUpdate.keySet()) {
            accountMeetingCounts.put(accId, 0);
        }
        
        // Count meetings that occurred between account creation date and conversion date (if exists)
        for(Event evt : [SELECT Id, WhatId, ActivityDate, ActivityDateTime
                         FROM Event 
                         WHERE WhatId IN :accountIds]) {
            
            Account relatedAccount = accountsToUpdate.get(evt.WhatId);
            if(relatedAccount != null) {
                // Get the date to compare
                Date eventDate = evt.ActivityDate;
                if(eventDate == null && evt.ActivityDateTime != null) {
                    eventDate = Date.newInstance(
                        evt.ActivityDateTime.year(), 
                        evt.ActivityDateTime.month(), 
                        evt.ActivityDateTime.day()
                    );
                }
                
                if(eventDate != null) {
                    // Determine if the event is within the valid date range
                    Date startDate = relatedAccount.CreatedDate.date();
                    Date endDate = relatedAccount.Fecha_Conversi_n_MKT__c != null ? 
                                 relatedAccount.Fecha_Conversi_n_MKT__c : Date.today();
                    
                    if(eventDate >= startDate && eventDate <= endDate) {
                        // Increment the meeting count
                        Integer currentCount = accountMeetingCounts.get(evt.WhatId);
                        accountMeetingCounts.put(evt.WhatId, currentCount + 1);
                    }
                }
            }
        }
        
        // Update all accounts with their new meeting counts
        List<Account> accountsList = new List<Account>();
        for(Id accId : accountMeetingCounts.keySet()) {
            Account accToUpdate = accountsToUpdate.get(accId);
            if(accToUpdate != null) {
                accToUpdate.ATV_Total_Reuniones__c = accountMeetingCounts.get(accId);
                accountsList.add(accToUpdate);
            }
        }
        
        if(!accountsList.isEmpty()) {
            update accountsList;
        }
    }
    
    /**
     * @description: Updates the call counts for accounts - only counts calls with subject starting with "R -"
     * @param accountIds - Set of Account IDs to update
     */
    public static void updateAccountCallCounts(Set<Id> accountIds) {
        if(accountIds == null || accountIds.isEmpty()) return;
        
        // Get all accounts with their creation date and conversion date
        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();
        for(Account acc : [SELECT Id, CreatedDate, Fecha_Conversi_n_MKT__c, ATV_Total_Llamadas__c 
                           FROM Account 
                           WHERE Id IN :accountIds]) {
            accountsToUpdate.put(acc.Id, acc);
        }
        
        // Query all task calls for these accounts
        Map<Id, Integer> accountCallCounts = new Map<Id, Integer>();
        
        // Initialize count to 0 for all accounts
        for(Id accId : accountsToUpdate.keySet()) {
            accountCallCounts.put(accId, 0);
        }
        
        // Count call tasks that occurred between account creation date and conversion date
        // Only count tasks that are calls and whose subject starts with "R -"
        for(Task t : [SELECT Id, WhatId, ActivityDate, TaskSubtype, Subject
                      FROM Task 
                      WHERE WhatId IN :accountIds
                      AND TaskSubtype = 'Call'
                      AND Subject LIKE 'R -%']) {
            
            Account relatedAccount = accountsToUpdate.get(t.WhatId);
            if(relatedAccount != null) {
                // Get the date to compare
                Date taskDate = t.ActivityDate;
                
                if(taskDate != null) {
                    // Determine if the task is within the valid date range
                    Date startDate = relatedAccount.CreatedDate.date();
                    Date endDate = relatedAccount.Fecha_Conversi_n_MKT__c != null ? 
                                 relatedAccount.Fecha_Conversi_n_MKT__c : Date.today();
                    
                    if(taskDate >= startDate && taskDate <= endDate) {
                        // Increment the call count
                        Integer currentCount = accountCallCounts.get(t.WhatId);
                        accountCallCounts.put(t.WhatId, currentCount + 1);
                    }
                }
            }
        }
        
        // Update all accounts with their new call counts
        List<Account> accountsList = new List<Account>();
        for(Id accId : accountCallCounts.keySet()) {
            Account accToUpdate = accountsToUpdate.get(accId);
            if(accToUpdate != null) {
                accToUpdate.ATV_Total_Llamadas__c = accountCallCounts.get(accId);
                accountsList.add(accToUpdate);
            }
        }
        
        if(!accountsList.isEmpty()) {
            update accountsList;
        }
    }
    
    /**
     * @description: Updates both meeting and call counts for accounts
     * @param accountIds - Set of Account IDs to update
     */
    public static void updateAccountCallAndMeetingCounts(Set<Id> accountIds) {
        updateAccountMeetingCounts(accountIds);
        updateAccountCallCounts(accountIds);
    }
}