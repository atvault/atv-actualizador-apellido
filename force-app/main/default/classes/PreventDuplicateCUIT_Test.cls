@isTest
public class PreventDuplicateCUIT_Test {

    @isTest
    static void testPreventDuplicateCUIT_NoConflict() {
        // Crear una Account con un CUIT único (Decimal)
        Account acc = new Account(
            Name = 'Empresa Única', 
            CUIT__c = Decimal.valueOf('30594465497')
        );
        insert acc;

        // Crear un Lead con un CUIT diferente (Decimal) sin conflictos
        Lead lead = new Lead(
            FirstName = 'Juan',
            LastName = 'Pérez',
            Company = 'Empresa Prueba',
            CUIT__c = Decimal.valueOf('20987654321'), // Asignamos Decimal correctamente
            Phone = '1234567890',
            Email = 'juan.perez@example.com'
        );

        Test.startTest();
        insert lead;
        Test.stopTest();

        // Validar que el Lead se creó correctamente
        Lead insertedLead = [SELECT Id, CUIT__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(lead.CUIT__c, insertedLead.CUIT__c, 
            'El Lead debería haberse creado sin problemas.');
    }

    @isTest
    static void testPreventDuplicateCUIT_WithConflict() {
        // Crear una Account con un CUIT existente (Decimal)
        Account acc = new Account(
            Name = 'Empresa Conflicto', 
            CUIT__c = Decimal.valueOf('30594465497')
        );
        insert acc;

        // Intentar crear un Lead con el mismo CUIT (Decimal)
        Lead lead = new Lead(
            FirstName = 'Carlos',
            LastName = 'Gómez',
            Company = 'Empresa Duplicada',
            CUIT__c = Decimal.valueOf('30594465497'), 
            Phone = '1234567890',
            Email = 'carlos.gomez@example.com'
        );

        Test.startTest();
        try {
            insert lead;
            // Si llega aquí, significa que NO se bloqueó como debería
            System.assert(false, 'ERROR: El Lead debería haber sido bloqueado por el trigger debido al conflicto de CUIT.');
        } catch (DmlException e) {
            // Validar que el mensaje de error contenga la advertencia esperada
            System.debug('MENSAJE DE ERROR: ' + e.getMessage());
            System.assert(e.getMessage().contains('Ya existe una cuenta con este CUIT'), 
                'El mensaje de error no coincide con el esperado. Mensaje real: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testPreventDuplicateCUIT_NullCUIT() {
        // Crear un Lead sin CUIT
        Lead lead = new Lead(
            FirstName = 'Ana',
            LastName = 'Martínez',
            Company = 'Empresa Sin CUIT',
            Phone = '0987654321',
            Email = 'ana.martinez@example.com'
        );

        Test.startTest();
        insert lead;
        Test.stopTest();

        // Validar que el Lead se creó correctamente sin CUIT
        Lead insertedLead = [SELECT Id, CUIT__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(null, insertedLead.CUIT__c, 'El Lead debería haberse creado sin CUIT.');
    }
}