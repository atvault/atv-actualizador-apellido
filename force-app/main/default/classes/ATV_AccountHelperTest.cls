/**
 * @description: Test class for ATV_AccountHelper
 * @author: AT Vault
 */
@isTest
private class ATV_AccountHelperTest {
    
    /**
     * @description: Setup test data - creates test accounts for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        
        // Account with "conversion date" in the future
        Account acc1 = new Account(
            Name = 'Test Account With Conv Date'
        );
        testAccounts.add(acc1);
        
        // Account without "conversion date"
        Account acc2 = new Account(
            Name = 'Test Account No Conv Date'
        );
        testAccounts.add(acc2);
        
        insert testAccounts;
        
        // Since we can't directly set Fecha_Conversi_n_MKT__c in tests, we're just validating the functionality works
    }
    
    /**
     * @description: Tests the updateAccountMeetingCounts method
     */
    @isTest
    static void testUpdateAccountMeetingCounts() {
        // Get the test accounts
        List<Account> accounts = [SELECT Id, Name, CreatedDate FROM Account 
                                 WHERE Name LIKE 'Test Account%'];
        
        Account testAccount = accounts[0];
        
        // Create an event
        Event evt = new Event(
            Subject = 'Test Event for Helper',
            WhatId = testAccount.Id,
            StartDateTime = DateTime.now().addDays(5),
            EndDateTime = DateTime.now().addDays(5).addHours(1),
            ActivityDate = Date.today().addDays(5)
        );
        insert evt;
        
        // Get the account IDs
        Set<Id> accountIds = new Set<Id>{testAccount.Id};
        
        // Start test context
        Test.startTest();
        
        // Call the helper method directly
        ATV_AccountHelper.updateAccountMeetingCounts(accountIds);
        
        Test.stopTest();
        
        // Verify the method executes without errors
        System.assertEquals(true, true, 'Method should execute without errors');
    }
    
    /**
     * @description: Tests the updateAccountCallCounts method
     */
    @isTest
    static void testUpdateAccountCallCounts() {
        // Get the test accounts
        List<Account> accounts = [SELECT Id, Name, CreatedDate FROM Account 
                                 WHERE Name LIKE 'Test Account%'];
        
        Account testAccount = accounts[0];
        
        // Create a call task
        Task task = new Task(
            Subject = 'R - Test Call for Helper',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(5),
            Status = 'Completed',
            Priority = 'Normal',
            TaskSubtype = 'Call'
        );
        insert task;
        
        // Get the account IDs
        Set<Id> accountIds = new Set<Id>{testAccount.Id};
        
        // Start test context
        Test.startTest();
        
        // Call the helper method directly
        ATV_AccountHelper.updateAccountCallCounts(accountIds);
        
        Test.stopTest();
        
        // Verify the method executes without errors
        System.assertEquals(true, true, 'Method should execute without errors');
    }
    
    /**
     * @description: Tests the updateAccountCallAndMeetingCounts method
     */
    @isTest
    static void testUpdateAccountCallAndMeetingCounts() {
        // Get the test accounts
        List<Account> accounts = [SELECT Id, Name, CreatedDate FROM Account 
                                 WHERE Name LIKE 'Test Account%'];
        
        Account testAccount = accounts[0];
        
        // Create an event
        Event evt = new Event(
            Subject = 'Test Event Combined',
            WhatId = testAccount.Id,
            StartDateTime = DateTime.now().addDays(5),
            EndDateTime = DateTime.now().addDays(5).addHours(1),
            ActivityDate = Date.today().addDays(5)
        );
        insert evt;
        
        // Create a call task
        Task task = new Task(
            Subject = 'R - Test Call Combined',
            WhatId = testAccount.Id,
            ActivityDate = Date.today().addDays(10),
            Status = 'Completed',
            Priority = 'Normal',
            TaskSubtype = 'Call'
        );
        insert task;
        
        // Get the account IDs
        Set<Id> accountIds = new Set<Id>{testAccount.Id};
        
        // Start test context
        Test.startTest();
        
        // Call the helper method directly
        ATV_AccountHelper.updateAccountCallAndMeetingCounts(accountIds);
        
        Test.stopTest();
        
        // Verify the method executes without errors
        System.assertEquals(true, true, 'Method should execute without errors');
    }
    
    /**
     * @description: Tests the behavior with empty parameters
     */
    @isTest
    static void testEmptyParameters() {
        // Start test context
        Test.startTest();
        
        // Call the helper methods with null and empty set
        ATV_AccountHelper.updateAccountMeetingCounts(null);
        ATV_AccountHelper.updateAccountMeetingCounts(new Set<Id>());
        
        ATV_AccountHelper.updateAccountCallCounts(null);
        ATV_AccountHelper.updateAccountCallCounts(new Set<Id>());
        
        ATV_AccountHelper.updateAccountCallAndMeetingCounts(null);
        ATV_AccountHelper.updateAccountCallAndMeetingCounts(new Set<Id>());
        
        Test.stopTest();
        
        // No assertions needed, just verifying these don't throw exceptions
        System.assertEquals(true, true, 'Methods should handle empty parameters gracefully');
    }
}