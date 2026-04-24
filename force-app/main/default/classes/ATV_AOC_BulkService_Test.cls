@IsTest
private class ATV_AOC_BulkService_Test {
    @IsTest
    static void testFetch() {
        Test.setMock(HttpCalloutMock.class, new Test_HttpMock());

        Account a1 = new Account(Name='A1'); insert a1;
        Contact c1 = new Contact(LastName='L', AccountId=a1.Id); insert c1;
        AccountOpportunityConfig__c cfg = new AccountOpportunityConfig__c(
            Account__c=a1.Id, ContactoPrincipal__c=c1.Id, Competencia__c='OTRO', PuntoDeDolor__c='PRECIO;CALIDAD'
        );
        insert cfg;

        ATV_AOC_BulkService.Request req = new ATV_AOC_BulkService.Request();
        req.accountIds = new List<Id>{ a1.Id, '001000000000000AAA' };

        List<ATV_AOC_DTO> out = ATV_AOC_BulkService.fetch(new List<ATV_AOC_BulkService.Request>{ req });
        System.assertEquals(2, out.size());
        ATV_AOC_DTO r;
        for (ATV_AOC_DTO item : out) {
            if (item.accountId == a1.Id) { r = item; break; }
        }
        System.assertNotEquals(null, r, 'Debe existir respuesta para a1');
        System.assertEquals(cfg.Id, r.aocId);
        System.assertEquals(c1.Id, r.contactoPrincipalId);
        System.assertEquals('OTRO', r.competencia);
        System.assertEquals('PRECIO;CALIDAD', r.puntoDeDolor);
    }
}