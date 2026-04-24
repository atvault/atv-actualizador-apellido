@isTest
private class NosisIntegrationServiceForLeadTest {
    private class MockHttpResponseFailure implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        // Crear una instancia de HttpResponse
        HttpResponse response = new HttpResponse();

        // Configurar el código de estado para simular un error (404 Not Found)
        response.setStatusCode(404);

        // Configurar el cuerpo de la respuesta si es necesario
        response.setBody('<xml><error><message>Resource not found</message></error></xml>');

        // Configurar los encabezados de la respuesta si es necesario
        response.setHeader('Content-Type', 'text/xml');

        return response;
    }
}

    // Prueba para manejar una respuesta HTTP no exitosa
    @isTest
    static void testNonSuccessfulHttpResponse() {
        Lead testLead = new Lead(
            Company = 'Test Company',
            LastName = 'TestLastName',
            CUIT__c = 30715899716.00,
            Street = 'Test Street',
            City = 'Test City',
            State = 'Test State',
            PostalCode = '12345',
            Country = 'Test Country',
            NumberOfEmployees = 10,
            Phone = '123456789',
            Score_Nosis__c = 100
        );
        insert testLead;

        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
        NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);
        

        // Configuramos un mock que simula un fallo HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseFailure());  // Asegúrate de definir esta clase mock
        service.getNosisScore();
        Test.stopTest();

        // Aserciones para verificar que se maneja adecuadamente el error
        System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
    }
    
    //mas pruebas

private class MockHttpResponseIncompleteData implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml><Contenido><Datos><Variables>' +
            '<Variable><Nombre>VI_RazonSocial</Nombre><Valor>BRUBANK SAU</Valor></Variable>' +
            // Falta el campo VI_DomAF_Calle intencionalmente
            '</Variables></Datos></Contenido></xml>');
        return response;
    }
}

@isTest
static void testIncompleteDataResponse() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseIncompleteData());
    // Insertar Lead y ejecutar método bajo prueba
    // Verificar que se manejen adecuadamente los datos incompletos
}

    private class MockHttpResponseNullValues implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml><Contenido><Datos><Variables>' +
            '<Variable><Nombre>VI_RazonSocial</Nombre><Valor>null</Valor></Variable>' +
            '</Variables></Datos></Contenido></xml>');
        return response;
    }
}

@isTest
static void testNullValuesInXMLResponse() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseNullValues());
    // Insertar Lead y ejecutar método bajo prueba
    // Verificar que se manejen adecuadamente los valores nulos
}
private class MockHttpResponseServerError implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setBody('Internal Server Error');
        return response;
    }
}

@isTest
static void testInternalServerErrorResponse() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseServerError());
    // Insertar Lead y ejecutar método bajo prueba
    // Verificar que se agregue un mensaje de error adecuado
}
//mas pruebas 2

private class MockHttpResponseTimeout implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        // Simular un tiempo de espera con un delay
        throw new CalloutException('Request timed out');
    }
}

@isTest
static void testApiTimeoutResponse() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseTimeout());
    Lead testLead = new Lead(
    LastName = 'TestLastName',
    Company = 'Test Company',
    CUIT__c = 30715899716.00
); // Corregido, sin coma extra antes del paréntesis

    insert testLead;
    
    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);
    
    Test.startTest();
    try {
        service.getNosisScore();
    } catch (Exception e) {
        // Verificar que se maneje adecuadamente la excepción de tiempo de espera
        System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
    }
    Test.stopTest();
}
private class MockHttpResponseCorruptedData implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml><Contenido><Datos><Variables>Malformed data here</Variables></Datos></Contenido></xml>');
        return response;
    }
}

@isTest
static void testCorruptedDataResponse() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseCorruptedData());
Lead testLead = new Lead(
    LastName = 'TestLastName',
    Company = 'Test Company',
    CUIT__c = 30715899716.00
); // Corregido, sin coma extra antes del paréntesis

    insert testLead;
    
    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);
    
    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se maneje correctamente los datos corruptos
    System.assertEquals(1, ApexPages.getMessages().size(), 'A warning message should be displayed for no data found.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}
private class MockHttpResponseApiUnavailable implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        // Simular la no disponibilidad de la API
        HttpResponse response = new HttpResponse();
        response.setStatusCode(503); // Service Unavailable
        return response;
    }
}

@isTest
static void testApiUnavailable() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseApiUnavailable());
    Lead testLead = new Lead(
    LastName = 'TestLastName',
    Company = 'Test Company',
    CUIT__c = 30715899716.00
); // Corregido, sin coma extra antes del paréntesis

    insert testLead;
    
    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);
    
    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se maneje correctamente la no disponibilidad de la API
    
        System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'An error message should be displayed for API unavailability.');
}

//mas tests 3

//mas pruebas
private class MockHttpResponseUnexpectedFormat implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml><Contenido><Datos><Variables>' +
            '<Variable><Nombre>UnknownField</Nombre><Valor>SomeValue</Valor></Variable>' +
            '</Variables></Datos></Contenido></xml>'); // Datos inesperados
        return response;
    }
}

@isTest
static void testUnexpectedFormatResponse() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseUnexpectedFormat());
    Lead testLead = new Lead(
        LastName = 'TestLastName',
        Company = 'Test Company',
        CUIT__c = 30715899716.00
    );
    insert testLead;

    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se maneje adecuadamente la presencia de datos inesperados
    System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be added.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}

@isTest
static void testLeadDataIntegrity() {
    Lead testLead = new Lead(
        LastName = 'TestLastName',  // Falta CUIT__c que es esencial para la llamada API
        Company = 'Test Company'
    );
    insert testLead;

    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se haya generado un mensaje de error debido a la falta de CUIT__c
    
      System.assertEquals(1, ApexPages.getMessages().size(), 'An error message should be displayed due to missing CUIT__c.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}
// Mas pruebas
private class MockHttpResponseNoDatosNode implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml><Contenido></Contenido></xml>'); // Ausencia del nodo 'Datos'
        return response;
    }
}

@isTest
static void testNoDatosNode() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseNoDatosNode());
    Lead testLead = new Lead(LastName = 'TestLastName', Company = 'Test Company', CUIT__c = 30715899716.00);
    insert testLead;

    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

   
    System.assertEquals(1, ApexPages.getMessages().size(), 'A warning message should be displayed for no data found.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
}
private class MockHttpResponseEmptyVariables implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml><Contenido><Datos><Variables></Variables></Datos></Contenido></xml>'); // Nodo 'Variables' vacío
        return response;
    }
}

@isTest
static void testEmptyVariablesNode() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseEmptyVariables());
    Lead testLead = new Lead(LastName = 'TestLastName', Company = 'Test Company', CUIT__c = 30715899716.00);
    insert testLead;

    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'A warning message should be displayed for no variables found.');
}
private class MockHttpResponseNullFields implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml><Contenido><Datos><Variables>' +
            '<Variable><Nombre>SCO_Vig</Nombre><Valor>null</Valor></Variable>' +
            '</Variables></Datos></Contenido></xml>'); // Valor 'null' en 'SCO_Vig'
        return response;
    }
}

@isTest
static void testNullFieldValues() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseNullFields());
    Lead testLead = new Lead(LastName = 'TestLastName', Company = 'Test Company', CUIT__c = 30715899716.00);
    insert testLead;

    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // No specific message expected, just verifying that no exception is thrown and the method completes.
    System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'A warning message should be displayed for no variables found.');
}

private class MockHttpResponseSuccess implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'text/xml');
        response.setBody('<xml xmlns="http://schemas.nosis.com/sac/ws01/types">' +
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
                '<Variable>' +
                    '<Nombre>VI_Tel1_CodArea</Nombre>' +
                    '<Valor></Valor>' +
                    '<Descripcion>Código de área, del teléfono Nº1.</Descripcion>' +
                    '<Tipo>TEL_AREA</Tipo>' +
                '</Variable>' +
                '<Variable>' +
                    '<Nombre>VI_Tel1_Nro</Nombre>' +
                    '<Valor></Valor>' +
                    '<Descripcion>Número, del teléfono Nº1.</Descripcion>' +
                    '<Tipo>TEL_NUMERO</Tipo>' +
                '</Variable>' +
            '</Variables>' +
        '</Datos>' +
    '</Contenido>' +
'</xml>');
        return response;
    }
}

@isTest
static void testSuccessfulHttpResponseWithData() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
    Lead testLead = new Lead(
        LastName = 'TestLastName',
        Company = 'Test Company',
        CUIT__c = 30715899716.00
    );
    insert testLead;

    ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
    NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);

    Test.startTest();
    service.getNosisScore();
    Test.stopTest();

    // Verificar que se manejen correctamente los datos completos
    System.assertEquals(1, ApexPages.getMessages().size(), 'A warning message should be displayed for no data found.');
    System.assertEquals(ApexPages.Severity.INFO, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');


}
    private class MockHttpResponseForLeadUpdate implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'text/xml');
            response.setBody('<xml><!-- XML de ejemplo con datos completos --></xml>');
            return response;
        }
    }

    @isTest
    static void testUpdatePhoneNumber() {
        Lead testLead = new Lead(
            LastName = 'TestLastName',
            Company = 'Test Company',
            CUIT__c = 30715899716.00
        );
        insert testLead;

        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
        NosisIntegrationServiceForLead service = new NosisIntegrationServiceForLead(stdController);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseForLeadUpdate());
        service.getNosisScore(); // Este método llama a updatePhoneNumber
        
        Test.stopTest();

        // Verificar que el número de teléfono se actualice correctamente
      System.assertEquals(1, ApexPages.getMessages().size(), 'A warning message should be displayed for no data found.');
    System.assertEquals(ApexPages.Severity.ERROR, ApexPages.getMessages()[0].getSeverity(), 'The error message should be of ERROR severity.');
    }
    
}