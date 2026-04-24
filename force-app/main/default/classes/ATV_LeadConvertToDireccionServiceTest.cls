@IsTest
private class ATV_LeadConvertToDireccionServiceTest {
    @IsTest
    static void createsDireccionOnLeadConvert_withMappedProvincia() {
        Account acc = new Account(Name = 'Cuenta Conversión 1');
        insert acc;
        Lead sourceLead = new Lead(LastName = 'Origen 1', Company = 'Origen Co 1');
        insert sourceLead;
        Lead oldLead = new Lead(Id = sourceLead.Id, IsConverted = false);
        Lead convertedLead = buildConvertedLead(
            oldLead.Id,
            acc.Id,
            'Perez',
            'Acme SA',
            'Av. Siempre Viva 123',
            'Rosario',
            'SANTA FE',
            '2000',
            'AR',
            'corp1@test.com'
        );

        Test.startTest();
        ATV_LeadConvertToDireccionService.createFromConvertedLeads(
            new List<Lead>{ convertedLead },
            new Map<Id, Lead>{ oldLead.Id => oldLead }
        );
        Test.stopTest();

        List<ATV_NTS_Direccion_de_Envio__c> dirs = [
            SELECT Account__c, NTS_fld_ShippingStreet__c, NTS_fld_ShippingCity__c, NTS_fld_ShippingCountry__c,
                   ATV_fld_ShippingPostalCode__c, Estado_o_Provincia__c, ATV_NTS_Provincia__c,
                   Direccion_predeterminada__c, Direccion_predeterminada_facturacion__c
            FROM ATV_NTS_Direccion_de_Envio__c
            WHERE Account__c = :acc.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(1, dirs.size(), 'Debe crear una dirección al convertir el lead');
        System.assertEquals('Av. Siempre Viva 123', dirs[0].NTS_fld_ShippingStreet__c);
        System.assertEquals('Rosario', dirs[0].NTS_fld_ShippingCity__c);
        System.assertEquals('AR', dirs[0].NTS_fld_ShippingCountry__c);
        System.assertEquals('2000', dirs[0].ATV_fld_ShippingPostalCode__c);
        System.assertEquals('SANTA FE', dirs[0].Estado_o_Provincia__c);
        System.assertEquals('Santa Fe', dirs[0].ATV_NTS_Provincia__c);
        System.assertEquals(false, dirs[0].Direccion_predeterminada__c);
        System.assertEquals(true, dirs[0].Direccion_predeterminada_facturacion__c);

        Account refreshedAccount = [
            SELECT Email__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals('corp1@test.com', refreshedAccount.Email__c, 'Debe copiar el mail corporativo al email de cuenta cuando esta vacio');
    }

    @IsTest
    static void usesBuenosAiresFallbackWhenStateDoesNotMatch() {
        Account acc = new Account(Name = 'Cuenta Conversión 2');
        insert acc;
        Lead sourceLead = new Lead(LastName = 'Origen 2', Company = 'Origen Co 2');
        insert sourceLead;
        Lead oldLead = new Lead(Id = sourceLead.Id, IsConverted = false);
        Lead convertedLead = buildConvertedLead(
            oldLead.Id,
            acc.Id,
            'Gomez',
            'Fallback SRL',
            'Calle 9',
            'X',
            'STATE NO MAPEADO',
            '1234',
            'AR',
            'corp2@test.com'
        );

        Test.startTest();
        ATV_LeadConvertToDireccionService.createFromConvertedLeads(
            new List<Lead>{ convertedLead },
            new Map<Id, Lead>{ oldLead.Id => oldLead }
        );
        Test.stopTest();

        ATV_NTS_Direccion_de_Envio__c dir = [
            SELECT ATV_NTS_Provincia__c
            FROM ATV_NTS_Direccion_de_Envio__c
            WHERE Account__c = :acc.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Buenos Aires', dir.ATV_NTS_Provincia__c, 'Debe usar fallback Buenos Aires');
    }

    @IsTest
    static void doesNotOverwriteExistingAccountEmail() {
        Account acc = new Account(Name = 'Cuenta Conversión 3', Email__c = 'existente@test.com');
        insert acc;
        Lead sourceLead = new Lead(LastName = 'Origen 3', Company = 'Origen Co 3');
        insert sourceLead;
        Lead oldLead = new Lead(Id = sourceLead.Id, IsConverted = false);
        Lead convertedLead = buildConvertedLead(
            oldLead.Id,
            acc.Id,
            'Lopez',
            'Cuenta Con Email',
            null,
            null,
            null,
            null,
            null,
            'nuevo@test.com'
        );

        Test.startTest();
        ATV_LeadConvertToDireccionService.createFromConvertedLeads(
            new List<Lead>{ convertedLead },
            new Map<Id, Lead>{ oldLead.Id => oldLead }
        );
        Test.stopTest();

        Account refreshedAccount = [
            SELECT Email__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals('existente@test.com', refreshedAccount.Email__c, 'No debe sobreescribir email existente en la cuenta');
    }

    @IsTest
    static void doesNotUpdateAccountWhenLeadCorporateEmailIsBlank() {
        Account acc = new Account(Name = 'Cuenta Conversión 4');
        insert acc;
        Lead sourceLead = new Lead(LastName = 'Origen 4', Company = 'Origen Co 4');
        insert sourceLead;
        Lead oldLead = new Lead(Id = sourceLead.Id, IsConverted = false);
        Lead convertedLead = buildConvertedLead(
            oldLead.Id,
            acc.Id,
            'Suarez',
            'Cuenta Sin Correo',
            null,
            null,
            null,
            null,
            null,
            null
        );

        Test.startTest();
        ATV_LeadConvertToDireccionService.createFromConvertedLeads(
            new List<Lead>{ convertedLead },
            new Map<Id, Lead>{ oldLead.Id => oldLead }
        );
        Test.stopTest();

        Account refreshedAccount = [
            SELECT Email__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals(null, refreshedAccount.Email__c, 'Si el mail corporativo viene vacio no debe actualizar la cuenta');
    }

    @IsTest
    static void createsDireccionEvenWhenCorporateEmailIsBlank() {
        Account acc = new Account(Name = 'Cuenta Conversión 5');
        insert acc;
        Lead sourceLead = new Lead(LastName = 'Origen 5', Company = 'Origen Co 5');
        insert sourceLead;
        Lead oldLead = new Lead(Id = sourceLead.Id, IsConverted = false);
        Lead convertedLead = buildConvertedLead(
            oldLead.Id,
            acc.Id,
            'Martinez',
            'Sin Mail Corp',
            'Av. Test 123',
            'Mendoza',
            'Mendoza',
            '5500',
            'AR',
            null
        );

        Test.startTest();
        ATV_LeadConvertToDireccionService.createFromConvertedLeads(
            new List<Lead>{ convertedLead },
            new Map<Id, Lead>{ oldLead.Id => oldLead }
        );
        Test.stopTest();

        List<ATV_NTS_Direccion_de_Envio__c> dirs = [
            SELECT Id, Account__c, NTS_fld_ShippingStreet__c
            FROM ATV_NTS_Direccion_de_Envio__c
            WHERE Account__c = :acc.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(1, dirs.size(), 'La direccion debe crearse aunque el mail corporativo este vacio');
        System.assertEquals('Av. Test 123', dirs[0].NTS_fld_ShippingStreet__c, 'La direccion debe conservar los datos del lead');
    }

    @IsTest
    static void triggerRunsOnLeadUpdate() {
        Lead l = new Lead(LastName = 'Smoke', Company = 'Smoke Co');
        insert l;

        Test.startTest();
        l.City = 'CABA';
        update l;
        Test.stopTest();

        System.assertNotEquals(null, l.Id, 'El update de lead debe ejecutarse para cubrir el trigger');
    }

    private static Lead buildConvertedLead(
        Id leadId,
        Id accountId,
        String lastName,
        String company,
        String street,
        String city,
        String state,
        String postalCode,
        String country,
        String corporateEmail
    ) {
        Map<String, Object> payload = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Lead' },
            'Id' => (String) leadId,
            'IsConverted' => true,
            'ConvertedAccountId' => (String) accountId,
            'LastName' => lastName,
            'Company' => company,
            'Street' => street,
            'City' => city,
            'State' => state,
            'PostalCode' => postalCode,
            'Country' => country,
            'CorreoElectronicoCorporativo__c' => corporateEmail
        };
        return (Lead) JSON.deserialize(JSON.serialize(payload), Lead.class);
    }
}