@IsTest
private class ATV_SyncAccountAddressFromDireccionTest {
    @IsTest
    static void sync_sets_shipping_from_predeterminada() {
        Account acc = new Account(Name = 'Acc ship sync');
        insert acc;

        ATV_NTS_Direccion_de_Envio__c dir = new ATV_NTS_Direccion_de_Envio__c(
            Name = 'Dir ship',
            Account__c = acc.Id,
            Direccion_predeterminada__c = true,
            NTS_fld_ShippingStreet__c = 'Calle 1',
            NTS_fld_ShippingCity__c = 'Ciudad X',
            NTS_fld_ShippingCountry__c = 'AR',
            ATV_fld_ShippingPostalCode__c = '1000'
        );
        insert dir;

        Test.startTest();
        ATV_SyncAccountAddressFromDireccion.SyncResult r = ATV_SyncAccountAddressFromDireccion.sync(true);
        Test.stopTest();

        System.assertEquals(1, r.accountIdsToTouch);
        System.assertEquals(1, r.updatedOk);
        System.assertEquals(0, r.updatedErrors);

        acc = [
            SELECT ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals('CALLE 1', acc.ShippingStreet != null ? acc.ShippingStreet.toUpperCase() : null);
        System.assert(
            acc.ShippingCity == null ||
            acc.ShippingCity.toUpperCase() == 'CIUDAD X'
        );
        System.assertEquals('1000', acc.ShippingPostalCode);
        System.assert(acc.ShippingCountry == null || acc.ShippingCountry.toUpperCase() == 'AR');
    }

    @IsTest
    static void sync_sets_billing_from_predeterminada_facturacion() {
        Account acc = new Account(Name = 'Acc bill sync');
        insert acc;

        ATV_NTS_Direccion_de_Envio__c dir = new ATV_NTS_Direccion_de_Envio__c(
            Name = 'Dir bill',
            Account__c = acc.Id,
            Direccion_predeterminada_facturacion__c = true,
            NTS_fld_ShippingStreet__c = 'Fact 9',
            NTS_fld_ShippingCity__c = 'Rosario',
            NTS_fld_ShippingCountry__c = 'AR',
            ATV_fld_ShippingPostalCode__c = '2000'
        );
        insert dir;

        Test.startTest();
        ATV_SyncAccountAddressFromDireccion.SyncResult r = ATV_SyncAccountAddressFromDireccion.sync(true);
        Test.stopTest();

        System.assertEquals(1, r.accountIdsToTouch);
        acc = [
            SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals('FACT 9', acc.BillingStreet.toUpperCase());
        System.assertEquals('ROSARIO', acc.BillingCity.toUpperCase());
        System.assertEquals('2000', acc.BillingPostalCode);
        System.assertEquals('AR', acc.BillingCountry);
    }

    @IsTest
    static void sync_doCommit_false_does_not_update() {
        Account acc = new Account(Name = 'Acc dry');
        insert acc;

        insert new ATV_NTS_Direccion_de_Envio__c(
            Name = 'Dir dry',
            Account__c = acc.Id,
            Direccion_predeterminada__c = true,
            NTS_fld_ShippingStreet__c = 'No commit',
            NTS_fld_ShippingCountry__c = 'AR'
        );

        ATV_SyncAccountAddressFromDireccion.SyncResult r = ATV_SyncAccountAddressFromDireccion.sync(false);
        System.assertEquals(1, r.accountIdsToTouch);
        System.assertEquals(0, r.updatedOk);
        System.assertEquals(0, r.updatedErrors);
    }
}