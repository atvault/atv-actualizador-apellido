@isTest
public class HND_ContactTest {
    
	@isTest
    static void testContact() {
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        mock.setStaticResource('MockInsercionCuenta');
        mock.setStatusCode(200);
        
        Product2 productTest = TEST_Setup.createProduct2();
        insert productTest;
        
        Id standardPriceBook = Test.getStandardPricebookId();

        PricebookEntry pricebookEntry = new PricebookEntry();
        pricebookEntry.Pricebook2Id = standardPriceBook;
        pricebookEntry.Product2Id = productTest.Id;
        pricebookEntry.UnitPrice = 100.00;
        pricebookEntry.IsActive = true;
        insert pricebookEntry;
        
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        Account accountTest = TEST_Setup.insertAccount('Empresa A');
        accountTest.ID_Netsuite__c = 123123;
        insert accountTest;
        
        // ✅ Modificación: Agregamos email y teléfono para evitar el error de validación
        Contact contactTest = new Contact(
            FirstName = 'Contacto',
            LastName = 'A',
            AccountId = accountTest.Id,
            Phone = '1234567890',  // ✅ Agregamos un teléfono válido
            Email = 'test@example.com'  // ✅ Agregamos un email válido
        );
        insert contactTest;
        
        Opportunity opp = TEST_Setup.insertOpportunity('Opp A', contactTest.Id, accountTest.Id);
        insert opp;
        
        Quote quote = new Quote();
        quote.Name = 'Test';
        quote.ContactId = contactTest.Id;
        quote.OpportunityId = opp.Id;
        quote.Pricebook2Id = standardPriceBook;
        quote.BillingStreet = 'SiempreViva 123';
        quote.BillingCity= 'Springfield';
        quote.BillingCountry = 'Argentina';
        quote.BillingPostalCode = '123asd';        
        insert quote;
        
        QuoteLineItem qli = new QuoteLineItem();
        qli.Product2Id = productTest.Id;
        qli.PricebookEntryId = pricebookEntry.Id;
        qli.Quantity = 2;
        qli.UnitPrice = 122;
        qli.QuoteId = quote.Id;
        insert qli;
            
        quote.QuoteApproved__c = true;
        quote.Status = 'Accepted';
        update quote;
        
        Test.stopTest();
    }
}