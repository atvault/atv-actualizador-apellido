@isTest
private class NosisIntegrationServiceTest {
    
    @isTest
    static void testValidResponseFromAPI() {
        // Preparar los datos de prueba necesarios
        Account testAccount = new Account(Name = 'Test Account', CUIT__c = 30710051959.00);
        insert testAccount;
        
        // Configurar el contexto de pruebas
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
        NosisIntegrationService service = new NosisIntegrationService(sc);

        Test.startTest();
        service.getNosisScore();
        Test.stopTest();
        
        // Verificar resultados
        testAccount = [SELECT Score__c FROM Account WHERE Id = :testAccount.Id];
        System.assertNotEquals(null, testAccount.Score__c, 'The score should be updated.');
        System.assertEquals(443, testAccount.Score__c.intValue(), 'The score should be 443.');
    }

private class MockHttpResponseSuccess implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'text/xml');
        res.setBody('<xml xmlns=\"http://schemas.nosis.com/sac/ws01/types\">' +
            '<Contenido>' +
                '<Pedido>' +
                    '<Usuario>63286</Usuario>' +
                    '<Documento>30715899716</Documento>' +
                    '<VR>1</VR>' +
                    '<Timeout>300</Timeout>' +
                '</Pedido>' +
                '<Resultado>' +
                    '<Estado>200</Estado>' +
                    '<Novedad>OK</Novedad>' +
                    '<Tiempo>580</Tiempo>' +
                    '<FechaRecepcion>2024-04-16T19:47:54</FechaRecepcion>' +
                    '<Transaccion>081ee8f2-959f-43bb-86f6-a5db454002f8</Transaccion>' +
                    '<Referencia>30715899716</Referencia>' +
                    '<Servidor>SACWEBZ13</Servidor>' +
                    '<Version>1.3.0</Version>' +
                '</Resultado>' +
                '<Datos>' +
                    '<Variables>' +
                        '<Variable>' +
                            '<Nombre>VI_RazonSocial</Nombre>' +
                            '<Valor>BRUBANK SAU</Valor>' +
                            '<Descripcion>Razón social</Descripcion>' +
                            '<Tipo>TEXTO</Tipo>' +
                            '<FechaAct>2024-03-28</FechaAct>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_Identificacion</Nombre>' +
                            '<Valor>30715899716</Valor>' +
                            '<Descripcion>CUIT / CUIL / CDI</Descripcion>' +
                            '<Tipo>DOCUMENTO</Tipo>' +
                            '<FechaAct>2024-03-28</FechaAct>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Calle</Nombre>' +
                            '<Valor>AV DEL LIBERTADOR</Valor>' +
                            '<Descripcion>Calle</Descripcion>' +
                            '<Tipo>TEXTO</Tipo>' +
                            '<FechaAct>2024-03-28</FechaAct>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Nro</Nombre>' +
                            '<Valor>174</Valor>' +
                            '<Descripcion>Número</Descripcion>' +
                            '<Tipo>TEXTO</Tipo>' +
                            '<FechaAct>2024-03-28</FechaAct>' +
                        '</Variable>' +
                        // ... Resto de las variables ...
                        '<Variable>' +
                            '<Nombre>SCO_Vig</Nombre>' +
                            '<Valor>443</Valor>' +
                            '<Descripcion>Score</Descripcion>' +
                            '<Tipo>ENTERO</Tipo>' +
                        '</Variable>' +
                        // ... Añade más variables si es necesario ...
                    '</Variables>' +
                '</Datos>' +
            '</Contenido>' +
            '</xml>'
        );
        res.setStatusCode(200);
        return res;
    }
}

@isTest
static void testSuccessfulNosisScoreRetrieval() {
    Account testAccount = new Account(Name = 'Test Account', CUIT__c = 30710051959.00, Score__c = null);
    insert testAccount;

    ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
    NosisIntegrationService service = new NosisIntegrationService(sc);

    Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    testAccount = [SELECT Score__c FROM Account WHERE Id = :testAccount.Id];
    System.assertNotEquals(null, testAccount.Score__c, 'The score should be updated.');
    System.assertEquals(443, testAccount.Score__c.intValue(), 'The score should be 443.');
}
@isTest
static void testFailedHTTPResponse() {
    // Configurar el contexto de pruebas para una respuesta HTTP fallida
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseFailure());

    // Intentar obtener la puntuación de Nosis
    Account testAccount = new Account(Name = 'Test Account', CUIT__c = 30710051959.00);
    insert testAccount;
    ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
    NosisIntegrationService service = new NosisIntegrationService(sc);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se haya agregado un mensaje de error
    System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}

@isTest
static void testExceptionDuringAPICall() {
    // Configurar el contexto de pruebas para lanzar una excepción durante la llamada a la API
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseException());

    // Intentar obtener la puntuación de Nosis
    Account testAccount = new Account(Name = 'Test Account', CUIT__c = 30710051959.00);
    insert testAccount;
    ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
    NosisIntegrationService service = new NosisIntegrationService(sc);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se haya agregado un mensaje de error
    System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}


    // Clase Mock para simular una respuesta HTTP fallida
    private class MockHttpResponseFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(404); // Simular una respuesta 404 Not Found
            return res;
        }
    }
 private class MockHttpResponseException extends Exception implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(500);
        res.setStatus('Internal Server Error');
        res.setBody('Error occurred during API call');
        return res;
    }
}

@isTest
static void testNon200HTTPResponse() {
    // Configurar el contexto de pruebas para una respuesta HTTP con estado diferente de 200
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseNon200());

    // Intentar obtener la puntuación de Nosis
    Account testAccount = new Account(Name = 'Test Account', CUIT__c = 30710051959.00);
    insert testAccount;
    ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
    NosisIntegrationService service = new NosisIntegrationService(sc);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se haya agregado un mensaje de error
    System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}

private class MockHttpResponseNon200 implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(404); // Simular una respuesta 404 Not Found
        return res;
    }
}
//maspruebas

    // Definir las clases de simulación de respuesta

    // Clase Mock para simular una respuesta API no disponible
    private class MockHttpResponseApiUnavailable implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(503); // Simular una respuesta 503 Service Unavailable
            return res;
        }
    }

    // Clase Mock para simular datos XML incompletos en la respuesta
    private class MockHttpResponseIncompleteData implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setBody('<xml>' +
                        '<Contenido>' +
                            // Falta la sección de Datos y Variables
                        '</Contenido>' +
                    '</xml>'); // Simular datos XML incompletos
            res.setStatusCode(200);
            return res;
        }
    }

    // Clase Mock para simular valores nulos en la respuesta XML
    private class MockHttpResponseNullValues implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setBody('<xml>' +
                        '<Contenido>' +
                            '<Datos>' +
                                '<Variables>' +
                                    '<Variable>' +
                                        '<Nombre>VI_RazonSocial</Nombre>' +
                                        '<Valor>null</Valor>' + // Simular valor nulo
                                        '<Descripcion>Razón social</Descripcion>' +
                                        '<Tipo>TEXTO</Tipo>' +
                                        '<FechaAct>2024-03-28</FechaAct>' +
                                    '</Variable>' +
                                    // Aquí puedes agregar más variables con valores nulos si es necesario
                                '</Variables>' +
                            '</Datos>' +
                        '</Contenido>' +
                    '</xml>'); // Simular valores nulos en la respuesta XML
            res.setStatusCode(200);
            return res;
        }
    }

    
@isTest
static void testApiUnavailable() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseApiUnavailable());
    // Crea una instancia de NosisIntegrationService y llama a getNosisScore
    // Verifica que se agregue un mensaje de error adecuado
}

@isTest
static void testMissingAccountData() {
    // Crea una instancia de NosisIntegrationService sin proporcionar un Id de cuenta
    // Verifica que se agregue un mensaje de error adecuado
}


@isTest
static void testIncompleteXMLData() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseIncompleteData());
    // Crea una instancia de NosisIntegrationService y llama a getNosisScore
    // Verifica que se maneje adecuadamente la respuesta XML incompleta
}

@isTest
static void testExceptionDuringResponseProcessing() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
    // Simula una excepción durante el procesamiento de la respuesta XML
    // Verifica que se maneje adecuadamente la excepción
}

@isTest
static void testNullValuesInXMLResponse() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseNullValues());
    // Crea una instancia de NosisIntegrationService y llama a getNosisScore
    // Verifica que se manejen adecuadamente los valores nulos en la respuesta XML
}
//mas pruebas 2

    @isTest
static void testInternalServerErrorResponse() {
    // Configurar el contexto de pruebas para simular una respuesta HTTP 500
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseServerError());

    Account testAccount = new Account(Name = 'Test Account', CUIT__c = 30710051959.00);
    insert testAccount;
    ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
    NosisIntegrationService service = new NosisIntegrationService(sc);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se maneje correctamente el error interno del servidor
    System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}

// Clase Mock para simular una respuesta de error interno del servidor
private class MockHttpResponseServerError implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(500);
        res.setBody('Internal Server Error');
        return res;
    }
}

//mas pruebas 3

@isTest
static void testGetNosisScoreWithNullAccountOrCUIT() {
    Account testAccount = new Account(Name = 'Test Account'); // CUIT__c es null por defecto
    insert testAccount;
    ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
    NosisIntegrationService service = new NosisIntegrationService(sc);
    service.getNosisScore();
    
    System.assert(ApexPages.hasMessages(), 'Should have an error message about missing CUIT information.');
}
    private class MockHttpResponseWithVariousValues implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'text/xml');
        res.setBody('<xml xmlns="http://schemas.nosis.com/sac/ws01/types">' +
            '<Contenido>' +
                '<Datos>' +
                    '<Variables>' +
                        '<Variable>' +
                            '<Nombre>SCO_Vig</Nombre>' +
                            '<Valor>450</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_Empleados_Cant</Nombre>' +
                            '<Valor>100</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Calle</Nombre>' +
                            '<Valor>AV SIEMPRE VIVA</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Nro</Nombre>' +
                            '<Valor>742</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Piso</Nombre>' +
                            '<Valor>2</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Dto</Nombre>' +
                            '<Valor>4B</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Loc</Nombre>' +
                            '<Valor>SPRINGFIELD</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_CP</Nombre>' +
                            '<Valor>12345</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_DomAF_Prov</Nombre>' +
                            '<Valor>Springfield State</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_Tel1_CodArea</Nombre>' +
                            '<Valor>011</Valor>' +
                        '</Variable>' +
                        '<Variable>' +
                            '<Nombre>VI_Tel1_Nro</Nombre>' +
                            '<Valor>555-1234</Valor>' +
                        '</Variable>' +
                    '</Variables>' +
                '</Datos>' +
            '</Contenido>' +
            '</xml>');
        res.setStatusCode(200);
        return res;
    }
}

@isTest
static void testProcessResponseWithVariousNodeValues() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseWithVariousValues());
    Account testAccount = new Account(Name = 'Test Account', CUIT__c = 30710051959.00);
    insert testAccount;

    ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
    NosisIntegrationService service = new NosisIntegrationService(sc);
    
    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    testAccount = [SELECT Score__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone FROM Account WHERE Id = :testAccount.Id];
    System.assertNotEquals(null, testAccount.Score__c, 'The score should be updated.');
    System.assertNotEquals(null, testAccount.BillingStreet, 'BillingStreet should be updated.');
    // Continúa con aserciones para cada campo esperado
}

}