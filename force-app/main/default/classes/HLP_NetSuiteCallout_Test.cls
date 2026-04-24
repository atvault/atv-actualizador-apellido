@IsTest
private class HLP_NetSuiteCallout_Test {

    @IsTest static void testGetCredentials_UAT_env() {
        HLP_NetSuiteCallout.overrideIsSandbox = true;
        NetSuite_Credential__mdt cred = HLP_NetSuiteCallout.getCredentials();
        System.assert(
            cred.Account__c != null && cred.Account__c.endsWith('_SB1'),
            '❌ getCredentials: en sandbox Account__c debería terminar con "_SB1": ' + cred.Account__c
        );
    }

    @IsTest static void testCreateHeader_Add() {
        HLP_NetSuiteCallout.overrideIsSandbox = true;
        Dom.Document doc = new Dom.Document();
        HLP_NetSuiteCallout.createHeader(doc, 'add');
        String xml = doc.toXmlString();
        System.assert(
            xml.contains(HLP_NetSuiteCallout.getCredentials().Account__c),
            '❌ createHeader: XML no contiene Account__c: ' + xml
        );
    }

    private class DummyHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
              '<?xml version="1.0"?>' +
              '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                  '<addResponse xmlns="urn:messages_2022_2.platform.webservices.netsuite.com">' +
                    '<writeResponse>' +
                      '<status xmlns="urn:core_2022_2.platform.webservices.netsuite.com" isSuccess="true"/>' +
                      '<baseRef internalId="555"/>' +
                    '</writeResponse>' +
                  '</addResponse>' +
                '</soapenv:Body>' +
              '</soapenv:Envelope>'
            );
            return res;
        }
    }

    @IsTest static void testSendRequestAndProcess_Add() {
        HLP_NetSuiteCallout.overrideIsSandbox = true;
        Test.setMock(HttpCalloutMock.class, new DummyHttpMock());
        Dom.Document doc = new Dom.Document();
        HLP_NetSuiteCallout.createHeader(doc, 'add');
        HttpResponse res = HLP_NetSuiteCallout.sendRequest(doc, 'https://test.endpoint', 'add');
        System.assertEquals(200, res.getStatusCode(), '❌ sendRequest no devolvió 200');
        Dom.Document respDoc = new Dom.Document();
        respDoc.load(res.getBody());
        String id = HLP_NetSuiteCallout.processResponse(respDoc, 'add');
        System.assertEquals('555', id, '❌ processResponse no extrajo internalId para add');
    }

    @IsTest static void testProcessResponse_UpdateList() {
        String xml =
          '<?xml version="1.0"?>' +
          '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
              '<updateListResponse xmlns="urn:messages_2022_2.platform.webservices.netsuite.com">' +
                '<writeResponseList>' +
                  '<writeResponse>' +
                    '<status xmlns="urn:core_2022_2.platform.webservices.netsuite.com" isSuccess="false"/>' +
                    '<baseRef internalId="888"/>' +
                  '</writeResponse>' +
                '</writeResponseList>' +
              '</updateListResponse>' +
            '</soapenv:Body>' +
          '</soapenv:Envelope>';
        Dom.Document respDoc = new Dom.Document();
        respDoc.load(xml);
        String result = HLP_NetSuiteCallout.processResponse(respDoc, 'updateList');
        System.assertEquals('888', result, '❌ processResponse debería retornar internalId incluso con isSuccess=false');
    }
}