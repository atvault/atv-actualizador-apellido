@isTest
public class BatchDuplicateActividadesArcaTest {

    @isTest
    static void testBatch() {
        Castle_Flags.updateContactCUIT = true;
        Account acc = TEST_Setup.insertAccount('Test');
        acc.ID_NetSuite__c = null;
        insert acc;

        Lead lead = new Lead();
        lead.LastName = 'Test';
        lead.Company = 'Test';
        lead.CUIT__c = 23132121212L;
        insert lead;

        ATV_ACTIVIDADES_ARCA__c actividad = new ATV_ACTIVIDADES_ARCA__c();
        actividad.Account__c = acc.Id;
        actividad.PRIORIDAD__c = 1;
        actividad.RUBRO__c = '72';
        actividad.CODIGO_ACTIVIDAD__c = '264000';
        insert actividad;

        Test.startTest();
        	BatchDuplicateActividadesArca batch = new BatchDuplicateActividadesArca();
			Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}