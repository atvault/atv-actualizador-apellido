@IsTest
private class ATV_RepetitiveOppsBatch_Helpers_Test {
    @IsTest
    static void testBuildItemsByAccount_filtersByPBE_andMarksAccounts() {
        Id stdId = Test.getStandardPricebookId();
        // Datos: 1 cuenta, 2 productos (solo 1 con PBE)
        Account a = new Account(Name='ACC_HELPER', BillingCity='CABA'); insert a;
        Product2 pWith = new Product2(Name='P_WITH', IsActive=true); insert pWith;
        Product2 pWithout = new Product2(Name='P_WITHOUT', IsActive=true); insert pWithout;
        PricebookEntry bWith = new PricebookEntry(Pricebook2Id=stdId, Product2Id=pWith.Id, UnitPrice=10, IsActive=true); insert bWith;

        // due: dos AP, uno con PBE válido y otro sin PBE
        AccountProduct__c apWith = new AccountProduct__c(Cliente__c=a.Id, Producto__c=pWith.Id);
        AccountProduct__c apWithout = new AccountProduct__c(Cliente__c=a.Id, Producto__c=pWithout.Id);
        List<AccountProduct__c> due = new List<AccountProduct__c>{ apWith, apWithout };

        Map<Id, PricebookEntry> pbeByProduct = new Map<Id, PricebookEntry>{ pWith.Id => bWith };
        Set<Id> accountsWithPBE = new Set<Id>();

        Map<Id, List<AccountProduct__c>> items = ATV_RepetitiveOppsBatch.buildItemsByAccount(due, pbeByProduct, accountsWithPBE);

        System.assertEquals(1, items.size(), 'Solo debe incluir cuentas con AP que tengan PBE válido');
        System.assertEquals(1, items.get(a.Id).size(), 'Solo el AP con PBE debe entrar');
        System.assert(accountsWithPBE.contains(a.Id));
    }

    @IsTest
    static void testMapOwnersByAccount_returnsOwnerMap() {
        User u = [SELECT Id FROM User WHERE IsActive=true LIMIT 1];
        Account a1 = new Account(Name='ACC_O1', BillingCity='CABA', OwnerId=u.Id); insert a1;
        Account a2 = new Account(Name='ACC_O2', BillingCity='CABA', OwnerId=u.Id); insert a2;
        Map<Id, Id> ownersByAccountMap = ATV_RepetitiveOppsBatch.mapOwnersByAccount(new List<Account>{ a1, a2 });
        System.assertEquals(u.Id, ownersByAccountMap.get(a1.Id));
        System.assertEquals(u.Id, ownersByAccountMap.get(a2.Id));
    }

    @IsTest
    static void testRenameOpps_updatesNamePrefix() {
        Id stdId = Test.getStandardPricebookId();
        Account a = new Account(Name='ACC_RENAME', BillingCity='CABA'); insert a;
        // Oportunidad existente (el helper hace SOQL por Id)
        Opportunity o = new Opportunity(
            AccountId=a.Id,
            Name='Repetitiva - ' + a.Name + ' - pending',
            StageName='MQL',
            CloseDate=Date.today().addDays(30),
            Pricebook2Id=stdId,
            Type='Existing Business (R)'
        );
        insert o;

        Map<Id, String> nameByAccount = new Map<Id, String>{ a.Id => a.Name };
        List<Opportunity> oppsToInsert = new List<Opportunity>{ o };
        String prefix = 'Repetitiva - ';

        // Ejecutar helper (no hace DML, sólo setea Name en memoria tras consultar el Opp)
        ATV_RepetitiveOppsBatch.renameOpps(oppsToInsert, nameByAccount, prefix);

        System.assert(oppsToInsert[0].Name.startsWith('Repetitiva - ' + a.Name + ' -'));
    }
}