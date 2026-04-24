@IsTest
public class CloneTasksToLeadsBatchTest {

    @IsTest
    static void testCloneTasksToLeads() {
        List<Account> accList = new List<Account>();
        for(Integer i = 1; i <= 5; i++){
            String cuitStr = '2000000000' + i;
            accList.add(new Account(
                Name = 'Test Account ' + i,
                Estado__c = 'CUSTOMER-3 - CLIENTE NO CONTACTADO',
                ID_NetSuite__c = null,
                CUIT__c = Decimal.valueOf(cuitStr)
            ));
        }
        insert accList;

        // 2️⃣ Crear leads con el mismo CUIT
        List<Lead> leadList = new List<Lead>();
        for(Integer i = 1; i <= 5; i++){
            String cuitStr = '2000000000' + i;
            leadList.add(new Lead(
                FirstName = 'Lead ' + i,
                LastName = 'Test',
                Company = 'Test Company',
                CUIT__c = Decimal.valueOf(cuitStr)
                //Status = 'Open - Not Contacted'
            ));
        }
        insert leadList;

        List<Task> taskList = new List<Task>();
        for(Account acc : accList){
            taskList.add(new Task(
                Subject = 'Task for ' + acc.Name,
                Status = 'Not Started',
                Priority = 'Normal',
                WhatId = acc.Id
            ));
        }
        insert taskList;

        Test.startTest();
        Database.executeBatch(new CloneTasksToLeadsBatch(), 200);
        Test.stopTest();
    }
}