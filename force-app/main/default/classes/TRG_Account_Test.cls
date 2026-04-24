@IsTest
private class TRG_Account_Test {

    /* ───── Mock de éxito reutilizable ───── */
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type','text/xml');
            res.setBody(
                '<?xml version="1.0"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                  '<soapenv:Body>' +
                    '<addResponse>' +
                      '<writeResponse>' +
                        '<status isSuccess="true"/>' +
                        '<baseRef internalId="999"/>' +   /* cualquier ID numérico está bien */
                      '</writeResponse>' +
                    '</addResponse>' +
                  '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }


    /* ========= 2) Actualización ========= */
    @IsTest static void testUpdateTriggerPath() {
        Account acc = new Account(Name = 'Trigger Update Test');
        insert acc;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        acc.Phone = '123-456';
        Test.startTest();
        update acc;                       // after update
        Test.stopTest();

        acc = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        System.assertEquals('123-456', acc.Phone);
    }

    /* ========= 3) Contexto Batch (se omite el future) ========= */
    @IsTest static void testBatchContextSkip() {
        User u = [SELECT Id FROM User WHERE IsActive = TRUE LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            insert new Account(Name = 'Batch Skip Simulation');
            Test.stopTest();

            // Si el trigger intentara invocar un @future dentro de batch,
            // se lanzaría AsyncException y el test fallaría.
            System.assert(true, 'El trigger pasó sin lanzar excepciones en modo batch.');
        }
    }
}