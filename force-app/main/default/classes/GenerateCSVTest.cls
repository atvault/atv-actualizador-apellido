@IsTest
private class GenerateCSVTest {

    @IsTest
    static void testBatchAccountNoTaskCSV() {
		Castle_Flags.updateContactCUIT = true;
        // Crear cuentas de prueba
        List<Account> accList = new List<Account>();
        for(Integer i=1; i<=1; i++){ // Puedes crear varias cuentas
            accList.add(new Account(
                Name = 'Test Account ' + i,
                Estado__c = 'CUSTOMER-3 - CLIENTE NO CONTACTADO', // Valor de picklist válido
                Phone = '809-000-000' + i,
                TEL_FONO_ALTERNATIVO__c = '809-111-111' + i,
                Email__c = 'test' + i + '@test.com',
                ATV_Email_Alternativo__c = 'alt' + i + '@test.com',
                Nombre_Legal__c = 'Legal Name ' + i,
                BillingCountry = 'Dominican Republic',
                BillingState = 'Santo Domingo',
                BillingCity = 'Santo Domingo',
                BillingStreet = 'Calle ' + i,
                BillingPostalCode = '0000' + i,
                CUIT__c =  i,
                Cat__c = '81',
                AccountSource = 'Advertisement',
                Website = 'www.test' + i + '.com',
                Tipo_de_Contribuyente__c = 'Consumidor Final',
                ATV_Rango_de_Facturaci_n__c = '1',
                NumberOfEmployees = i*10,
                Rubro__c = '\N'
            ));
        }
        insert accList;

        // Ejecutar el batch
        Test.startTest();
        Database.executeBatch(new GenerateCSV(), 200);
        Test.stopTest();

        // Verificar que se hayan creado ContentVersion
        List<ContentVersion> cvs = [SELECT Id, Title, PathOnClient FROM ContentVersion WHERE Title LIKE 'AccountNoTask%'];
        System.assert(cvs.size() > 0, 'Se deben haber creado ContentVersion');
    }
}