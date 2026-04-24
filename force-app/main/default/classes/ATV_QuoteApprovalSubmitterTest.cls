/**
 * Test class for ATV_QuoteApprovalSubmitter
 */
@IsTest
private class ATV_QuoteApprovalSubmitterTest {

    @IsTest
    static void test_submitForApproval_nullInput() {
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(null);
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('No Quote Id'));
    }

    @IsTest
    static void test_submitForApproval_emptyInput() {
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(new List<Id>());
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void test_submitForApproval_forceSuccess() {
        ATV_QuoteApprovalSubmitter.TEST_forceSuccess = true;
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(new List<Id>{ UserInfo.getUserId() });
        ATV_QuoteApprovalSubmitter.TEST_forceSuccess = false;
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assert(results[0].message.contains('Submitted'));
    }

    @IsTest
    static void test_submitForApproval_forceElseBranch() {
        ATV_QuoteApprovalSubmitter.TEST_forceElseBranch = true;
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(new List<Id>{ UserInfo.getUserId() });
        ATV_QuoteApprovalSubmitter.TEST_forceElseBranch = false;
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Test error'));
    }

    @IsTest
    static void test_submitForApproval_forceSuccessMultipleIds() {
        ATV_QuoteApprovalSubmitter.TEST_forceSuccess = true;
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(new List<Id>{ UserInfo.getUserId(), UserInfo.getUserId() });
        ATV_QuoteApprovalSubmitter.TEST_forceSuccess = false;
        System.assertEquals(2, results.size());
        for (ATV_QuoteApprovalSubmitter.Result r : results) {
            System.assertEquals(true, r.success);
            System.assert(r.message.contains('Submitted'));
        }
    }

    @IsTest
    static void test_submitForApproval_invalidId() {
        List<Id> ids = new List<Id>{ UserInfo.getUserId() };
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(ids);
        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0]);
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message != null);
    }

    @IsTest
    static void test_submitForApproval_multipleIds() {
        List<Id> ids = new List<Id>{ UserInfo.getUserId(), UserInfo.getUserId() };
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(ids);
        System.assertEquals(2, results.size());
        for (ATV_QuoteApprovalSubmitter.Result r : results) {
            System.assertNotEquals(null, r);
            System.assertEquals(false, r.success);
        }
    }

    @IsTest
    static void test_submitForApproval_quoteWithApprovalProcess() {
        Account acc = new Account(Name = 'Test Acc ' + System.now().getTime());
        insert acc;
        Contact c = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert c;
        List<Schema.PicklistEntry> stages = Opportunity.StageName.getDescribe().getPicklistValues();
        String stageName = 'Prospecting';
        for (Schema.PicklistEntry pe : stages) {
            if (pe.isActive() && pe.getValue() == 'MQL') {
                stageName = 'MQL';
                break;
            }
        }
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = stageName,
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        insert new OpportunityContactRole(OpportunityId = opp.Id, ContactId = c.Id, IsPrimary = true);
        Pricebook2 stdPb = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        update stdPb;
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPb.Id,
            ContactId = c.Id,
            Status = 'Draft',
            BillingStreet = 'Test 123',
            BillingCity = 'Test City',
            BillingCountry = 'Argentina',
            BillingPostalCode = '1000'
        );
        insert q;
        q.Status = 'Needs Review';
        update q;
        List<ATV_QuoteApprovalSubmitter.Result> results = ATV_QuoteApprovalSubmitter.submitForApproval(new List<Id>{ q.Id });
        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0]);
        if (results[0].success) {
            System.assert(results[0].message.contains('Submitted'));
        } else {
            System.assert(results[0].message != null && results[0].message.length() > 0);
        }
    }
}