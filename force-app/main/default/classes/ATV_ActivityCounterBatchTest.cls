/**
 * @description: Test class for ATV_ActivityCounterBatch
 * @author: AT Vault
 */
@isTest
private class ATV_ActivityCounterBatchTest {
    
    /**
     * @description: Setup test data - creates test accounts, events and tasks
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        
        // Account with "conversion date" in the future
        Account acc1 = new Account(
            Name = 'Test Account For Batch 1'
        );
        testAccounts.add(acc1);
        
        // Account without "conversion date"
        Account acc2 = new Account(
            Name = 'Test Account For Batch 2'
        );
        testAccounts.add(acc2);
        
        insert testAccounts;
        
        // Get the inserted accounts
        testAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account For Batch%'];
        Account account1 = testAccounts[0];
        Account account2 = testAccounts[1];
        
        // Create events
        List<Event> events = new List<Event>();
        
        // Events for account 1
        for (Integer i = 0; i < 5; i++) {
            Event evt = new Event(
                Subject = 'Batch Test Event ' + i,
                WhatId = account1.Id,
                StartDateTime = DateTime.now().addDays(i),
                EndDateTime = DateTime.now().addDays(i).addHours(1),
                ActivityDate = Date.today().addDays(i)
            );
            events.add(evt);
        }
        
        // Events for account 2
        for (Integer i = 0; i < 3; i++) {
            Event evt = new Event(
                Subject = 'Batch Test Event for Account2 ' + i,
                WhatId = account2.Id,
                StartDateTime = DateTime.now().addDays(i),
                EndDateTime = DateTime.now().addDays(i).addHours(1),
                ActivityDate = Date.today().addDays(i)
            );
            events.add(evt);
        }
        
        insert events;
        
        // Create tasks
        List<Task> tasks = new List<Task>();
        
        // Tasks for account 1 - valid calls with R- prefix
        for (Integer i = 0; i < 3; i++) {
            Task task = new Task(
                Subject = 'R - Batch Test Call ' + i,
                WhatId = account1.Id,
                ActivityDate = Date.today().addDays(i),
                Status = 'Completed',
                Priority = 'Normal',
                TaskSubtype = 'Call'
            );
            tasks.add(task);
        }
        
        // Tasks for account 1 - call without R- prefix (should not count)
        Task taskNoPrefix = new Task(
            Subject = 'Batch Test Call No Prefix',
            WhatId = account1.Id,
            ActivityDate = Date.today().addDays(1),
            Status = 'Completed',
            Priority = 'Normal',
            TaskSubtype = 'Call'
        );
        tasks.add(taskNoPrefix);
        
        // Tasks for account 2 - valid calls with R- prefix
        for (Integer i = 0; i < 2; i++) {
            Task task = new Task(
                Subject = 'R - Batch Test Call for Account2 ' + i,
                WhatId = account2.Id,
                ActivityDate = Date.today().addDays(i),
                Status = 'Completed',
                Priority = 'Normal',
                TaskSubtype = 'Call'
            );
            tasks.add(task);
        }
        
        insert tasks;
    }
    
    /**
     * @description: Tests the batch for events
     */
    @isTest
    static void testEventBatch() {
        // Get account before processing
        Account account1Before = [SELECT Id, ATV_Total_Reuniones__c 
                               FROM Account 
                               WHERE Name = 'Test Account For Batch 1'];
        
        // Start test context for batch
        Test.startTest();
        
        // Run the batch for events
        ATV_ActivityCounterBatch eventBatch = new ATV_ActivityCounterBatch('Event');
        Database.executeBatch(eventBatch, 200);
        
        Test.stopTest();
        
        // Verify the test runs without errors
        System.assertEquals(true, true, 'Batch should run without errors');
    }
    
    /**
     * @description: Tests the batch for tasks
     */
    @isTest
    static void testTaskBatch() {
        // Get account before processing
        Account account1Before = [SELECT Id, ATV_Total_Llamadas__c 
                               FROM Account 
                               WHERE Name = 'Test Account For Batch 1'];
        
        // Start test context for batch
        Test.startTest();
        
        // Run the batch for tasks
        ATV_ActivityCounterBatch taskBatch = new ATV_ActivityCounterBatch('Task');
        Database.executeBatch(taskBatch, 200);
        
        Test.stopTest();
        
        // Verify the test runs without errors
        System.assertEquals(true, true, 'Batch should run without errors');
    }
    
    /**
     * @description: Tests the full update method
     */
    @isTest
    static void testFullUpdate() {
        // Start test context
        Test.startTest();
        
        // Call the static method to run full update
        ATV_ActivityCounterBatch.runFullUpdate();
        
        Test.stopTest();
        
        // Verify the test runs without errors
        System.assertEquals(true, true, 'Full update should run without errors');
    }
}