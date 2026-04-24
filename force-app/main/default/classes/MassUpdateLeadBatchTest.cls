@isTest
public class MassUpdateLeadBatchTest {

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
        con.MailingCountry = 'Test';
        con.MailingCity = 'Test';
        con.MailingStreet = null;
        con.MailingState = 'Test';
        con.MailingPostalCode = '12345';
        con.MailingLongitude = 2;
        con.MailingLatitude = 4;
        insert con;

        Contact con2 = TEST_Setup.insertContact(acc.name, acc.Id);
        con2.AccountId = null;
        con2.Candidato__c = lead.Id;
        insert con2;
        
        Test.startTest();
        	MassUpdateLeadBatch batch = new MassUpdateLeadBatch();
			Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}