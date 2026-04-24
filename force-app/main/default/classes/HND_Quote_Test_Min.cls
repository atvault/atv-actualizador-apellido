/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-24-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest(seeAllData=false)
public class HND_Quote_Test_Min {

    /* Mock NetSuite OK */
    private class OK implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body><addResponse xmlns="urn:messages_2022_2.platform.webservices.netsuite.com"><writeResponse><status isSuccess="true"/></writeResponse></addResponse></soapenv:Body></soapenv:Envelope>');
            return r;
        }
    }

    @IsTest static void accepted_runsCallout() {
        HLP_NetSuiteCallout.overrideIsSandbox = true;
        Test.setMock(HttpCalloutMock.class, new OK());

        /* Datos mínimos para un Quote válido */
        Product2 prod = TEST_Setup.createProduct2();
        insert prod;

        Pricebook2 stdPbRec = TEST_Setup.createStandardPricebook();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbRec.Id,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        Account acc = TEST_Setup.insertAccount('Empresa A');
        acc.ID_Netsuite__c = 123123;
        insert acc;

        Contact con = TEST_Setup.insertContact('Contacto A', acc.Id);

        // La regla de validación exige teléfono o email
        con.Phone = '5551234';

        insert con;

        Opportunity opp = TEST_Setup.insertOpportunity('Opp A', con.Id, acc.Id);
        insert opp;

        Quote q = new Quote(
            Name          = 'Test',
            OpportunityId = opp.Id,
            Pricebook2Id  = stdPbRec.Id,
            ContactId     = con.Id,
            BillingStreet = 'SiempreViva 123',
            BillingCity   = 'Springfield',
            BillingCountry = 'Argentina',
            BillingPostalCode = '123asd',
            QuoteApproved__c = true
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            PricebookEntryId = pbe.Id,
            Quantity         = 2,
            UnitPrice        = 122,
            QuoteId          = q.Id
        );
        insert qli;

        Map<Id,Quote> oldMap = new Map<Id,Quote>{
            q.Id => q.clone(false,false,false,false)
        };

        Test.startTest();
            q.Status = 'Accepted';
            update q;                            // dispara trigger
            HND_Quote.sendQuoteToNetSuite(
                new List<Quote>{q}, oldMap);     // llama al método
        Test.stopTest();

        System.assertEquals('Accepted',
            [SELECT Status FROM Quote WHERE Id = :q.Id].Status);
    }
}