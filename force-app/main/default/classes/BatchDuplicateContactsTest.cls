@isTest	
public class BatchDuplicateContactsTest {
    @isTest
    static void testBatch(){
        Castle_Flags.updateContactCUIT = true;
        Account acc = TEST_Setup.insertAccount('Test');
        acc.ID_NetSuite__c = null;
        insert acc;

        Lead lead = new Lead();
        lead.LastName = 'Test';
        lead.Company = 'Test';
        lead.CUIT__c = 23132121212L;
        insert lead;

		Contact con = TEST_Setup.insertContact(acc.name, acc.Id);
        insert con;
        
        Test.startTest();
        	BatchDuplicateContacts batch = new BatchDuplicateContacts();
			Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}