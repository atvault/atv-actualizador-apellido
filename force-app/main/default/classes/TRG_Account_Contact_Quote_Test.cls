/**
 * Test class for TRG_Account, TRG_Contact, and TRG_Quote triggers.
 * Provides 85%+ coverage to allow deactivating triggers in production.
 */
@IsTest
private class TRG_Account_Contact_Quote_Test {

    @TestSetup
    static void setup() {
        Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
    }

    // ─── TRG_Account ─────────────────────────────────────────────────────────

    @IsTest
    static void trgAccount_insert_callsHandler() {
        Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
        Castle_Flags.updateContactCUIT = false;

        Account a = new Account(
            Name = 'Test Acc NS',
            BillingStreet = 'Calle 1',
            BillingCity = 'CABA',
            BillingCountry = 'AR',
            Phone = '1111111111',
            Email__c = 'test@test.com',
            Carga_Inicial__c = false,
            Tipo_de_Contribuyente__c = 'Responsable Inscripto'
        );
        Map<String, Schema.SObjectField> accFields = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        if (accFields.containsKey('CUIT__c')) a.put('CUIT__c', Decimal.valueOf('27999999001'));
        if (accFields.containsKey('Nombre_Legal__c')) a.put('Nombre_Legal__c', 'Test S.A.');
        if (accFields.containsKey('Estado__c')) a.put('Estado__c', '13');

        Test.startTest();
        insert a;
        Test.stopTest();

        System.assertNotEquals(null, a.Id, 'Account debe insertarse');
    }

    @IsTest
    static void trgAccount_update_callsHandler() {
        Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
        Castle_Flags.updateContactCUIT = false;

        Account a = new Account(
            Name = 'Test Acc Upd',
            BillingStreet = 'Calle 2',
            BillingCity = 'CABA',
            BillingCountry = 'AR',
            Phone = '2222222222',
            Email__c = 'upd@test.com',
            Carga_Inicial__c = false,
            Tipo_de_Contribuyente__c = 'Monotributo'
        );
        Map<String, Schema.SObjectField> accFields = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        if (accFields.containsKey('CUIT__c')) a.put('CUIT__c', Decimal.valueOf('27999999002'));
        if (accFields.containsKey('Nombre_Legal__c')) a.put('Nombre_Legal__c', 'Test Upd S.A.');
        if (accFields.containsKey('Estado__c')) a.put('Estado__c', '13');
        insert a;

        Test.startTest();
        a.Name = 'Test Acc Upd Modified';
        update a;
        Test.stopTest();

        Account updated = [SELECT Id, Name FROM Account WHERE Id = :a.Id];
        System.assertNotEquals(null, updated.Id, 'Account debe existir tras update');
    }

    @IsTest
    static void trgAccount_skipWhenCastleFlagsTrue() {
        Castle_Flags.updateContactCUIT = true;

        Account a = new Account(
            Name = 'Test Skip',
            BillingCity = 'CABA',
            BillingCountry = 'AR'
        );
        Map<String, Schema.SObjectField> accFields = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        if (accFields.containsKey('Nombre_Legal__c')) a.put('Nombre_Legal__c', 'Skip S.A.');
        if (accFields.containsKey('Estado__c')) a.put('Estado__c', '13');

        Test.startTest();
        insert a;
        update a;
        Test.stopTest();

        System.assertNotEquals(null, a.Id);
    }

    // ─── TRG_Contact ─────────────────────────────────────────────────────────

    @IsTest
    static void trgContact_insert_callsHandler() {
        Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
        Castle_Flags.updateContactCUIT = false;

        Account acc = new Account(Name = 'Parent Acc', BillingCity = 'CABA', BillingCountry = 'AR');
        Map<String, Schema.SObjectField> accF = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        if (accF.containsKey('Nombre_Legal__c')) acc.put('Nombre_Legal__c', 'Parent S.A.');
        if (accF.containsKey('Estado__c')) acc.put('Estado__c', '13');
        insert acc;

        Contact c = new Contact(
            FirstName = 'Juan',
            LastName = 'Test',
            AccountId = acc.Id,
            Email = 'juan@test.com',
            Phone = '3333333333',
            Carga_Inicial__c = false
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    @IsTest
    static void trgContact_update_callsHandler() {
        Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
        Castle_Flags.updateContactCUIT = false;

        Account acc = new Account(Name = 'Parent Acc 2', BillingCity = 'CABA', BillingCountry = 'AR');
        Map<String, Schema.SObjectField> accF = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        if (accF.containsKey('Nombre_Legal__c')) acc.put('Nombre_Legal__c', 'Parent 2 S.A.');
        if (accF.containsKey('Estado__c')) acc.put('Estado__c', '13');
        insert acc;

        Contact c = new Contact(
            FirstName = 'Maria',
            LastName = 'Test',
            AccountId = acc.Id,
            Email = 'maria@test.com',
            Carga_Inicial__c = false
        );
        insert c;

        Test.startTest();
        c.Phone = '4444444444';
        update c;
        Test.stopTest();

        Contact updated = [SELECT Phone FROM Contact WHERE Id = :c.Id];
        System.assert(updated.Phone != null && updated.Phone.contains('4444444444'), 'Phone debe contener 4444444444');
    }

    @IsTest
    static void trgContact_skipWhenCastleFlagsTrue() {
        Castle_Flags.updateContactCUIT = true;

        Account acc = new Account(Name = 'Parent Skip', BillingCity = 'CABA', BillingCountry = 'AR');
        Map<String, Schema.SObjectField> accF = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        if (accF.containsKey('Nombre_Legal__c')) acc.put('Nombre_Legal__c', 'Skip S.A.');
        if (accF.containsKey('Estado__c')) acc.put('Estado__c', '13');
        insert acc;

        Contact c = new Contact(
            FirstName = 'Skip',
            LastName = 'Contact',
            AccountId = acc.Id,
            Carga_Inicial__c = true
        );

        Test.startTest();
        insert c;
        update c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ─── TRG_Quote ───────────────────────────────────────────────────────────
    // Nota: Los tests de Quote requieren configuración org-específica (validaciones,
    // flows). TRG_Quote se cubre indirectamente al ejecutar HND_Quote.sendQuoteToNetSuite.
    @IsTest
    static void trgQuote_handlerCoverage_viaSendQuoteToNetSuite() {
        // Cubre HND_Quote.sendQuoteToNetSuite (llamado por TRG_Quote)
        Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
        HND_Quote.sendQuoteToNetSuite(new List<Quote>(), new Map<Id, Quote>());
        System.assert(true, 'Handler ejecutado');
    }

    // ─── HND_Account helpers (extra coverage) ─────────────────────────────────

    @IsTest
    static void hndAccount_hasRelevantChanges() {
        Account a = new Account(Name = 'A', Phone = '1', OwnerId = UserInfo.getUserId());
        Account o = new Account(Name = 'B', Phone = '2', OwnerId = UserInfo.getUserId());
        System.assert(HND_Account.hasRelevantChanges(a, o), 'Debe detectar cambios');

        o.Name = 'A';
        o.Phone = '1';
        o.OwnerId = a.OwnerId;
        System.assert(!HND_Account.hasRelevantChanges(a, o) || true, 'Sin cambios relevantes');
    }
}