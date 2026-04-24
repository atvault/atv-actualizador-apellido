@isTest
private class CampaignHierarchyControllerTest {

    @isTest
    static void testGetCampaignHierarchy() {
        Campaign camp = new Campaign(
            Name = 'Test Campaign',
            IsActive = true,
            Status = 'In Progress'
        );
        insert camp;

        Lead lead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            CUIT__c = 12345 
        );
        insert lead;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        insert new CampaignMember(CampaignId = camp.Id, LeadId = lead.Id, Status = 'Sent');
        insert new CampaignMember(CampaignId = camp.Id, ContactId = con.Id, Status = 'Responded');

        Date today = Date.today();

        Task futureTask = new Task(
            Subject = 'Future Task',
            ActivityDate = today.addDays(5),
            WhoId = lead.Id,
            Status = 'Open' 
        );

        Task pastTask = new Task(
            Subject = 'Past Task',
            ActivityDate = today.addDays(-5),
            WhoId = lead.Id,
            Status = 'Completed'
        );

        Event futureEvent = new Event(
            Subject = 'Future Meeting',
            StartDateTime = Datetime.now().addDays(2),
            EndDateTime = Datetime.now().addDays(2).addHours(1),
            WhoId = lead.Id
        );

        insert new List<SObject>{ futureTask, pastTask, futureEvent };

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'MQL',
            CloseDate = today.addDays(30),
            CampaignId = camp.Id,
            AccountId = acc.Id,
            Amount = 1000
        );
        insert opp;

        Test.startTest();
        
        CampaignHierarchyController.CampaignDTO result = CampaignHierarchyController.getCampaignHierarchyById(camp.Id);
        
        List<CampaignHierarchyController.CampaignListItemDTO> listResult = CampaignHierarchyController.getAllActiveCampaigns();
        
        Test.stopTest();

        System.assertNotEquals(null, result, 'El resultado no debe ser nulo');
        System.assertEquals(camp.Name, result.name);
        System.assertEquals(1, result.opportunities.size(), 'Debe traer 1 oportunidad');
        System.assertEquals(2, result.members.size(), 'Debe traer 2 miembros');
        CampaignHierarchyController.MemberDTO leadMember;
        for(CampaignHierarchyController.MemberDTO m : result.members) {
            if(m.personId == lead.Id) leadMember = m;
        }

        System.assertNotEquals(null, leadMember.nextActivity, 'Debe tener una próxima actividad');
        System.assertEquals('Event', leadMember.nextActivity.type, 'La actividad más cercana debería ser el Evento');
        System.assertNotEquals(null, leadMember.lastCompletedActivity, 'Debe tener una actividad completada');
        System.assertEquals('Task', leadMember.lastCompletedActivity.type);

        System.assert(listResult.size() > 0, 'Debe retornar al menos una campaña');
        System.assertEquals(camp.Id, listResult[0].Id, 'La campaña con más opps debe estar primero');
        System.assertEquals(1, listResult[0].opportunityCount, 'El conteo de opps debe ser 1');
    }

}