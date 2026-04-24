@isTest
public class HND_Account_Test {
    private class MockNetSuiteCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?>' +
                        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                          '<soapenv:Body>' +
                            '<addResponse xmlns="urn:messages_2022_2.platform.webservices.netsuite.com">' +
                              '<writeResponse>' +
                                '<status xmlns="urn:core_2022_2.platform.webservices.netsuite.com" isSuccess="true"/>' +
                                '<baseRef internalId="12345"/>' +
                              '</writeResponse>' +
                            '</addResponse>' +
                          '</soapenv:Body>' +
                        '</soapenv:Envelope>');
            return res;
        }
    }

    @isTest
    static void testInsertAccount_createsCustomer() {
        Test.setMock(HttpCalloutMock.class, new MockNetSuiteCallout());

        // Creamos la cuenta con datos necesarios
        Account a = new Account(
            Name = 'Test Empresa',
            Phone = '123456789',
            Email__c = 'empresa@test.com',
            CUIT__c = 30500572309L,
            Website = 'https://example.com',
            Estado__c = '16', // TIP: corresponde al internal ID de entitystatus
            OwnerId = UserInfo.getUserId(),
            Rubro__c = '65',
            Cat__c = '81',
            Tipo_de_Contribuyente__c = 'Responsable Inscripto',
            Carga_Inicial__c = false
        );
        insert a;

        Test.startTest();
            HND_Account.createCustomer(a.Id);
        Test.stopTest();

        a = [SELECT ID_NetSuite__c FROM Account WHERE Id = :a.Id];
        System.assertEquals(12345, Integer.valueOf(a.ID_NetSuite__c));
    }
}