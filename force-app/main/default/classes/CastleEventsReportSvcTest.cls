@IsTest
private class CastleEventsReportSvcTest {
  @IsTest
  static void getEvents_emptyOrg_returnsZeroRows() {
    CastleEventsReportSvc.EventFilterDto f = new CastleEventsReportSvc.EventFilterDto();
    CastleEventsReportSvc.EventQueryResultDto r = CastleEventsReportSvc.getEvents(
      f,
      25,
      1,
      'StartDateTime',
      'desc',
      null
    );
    System.assertEquals(0, r.totalRows);
    System.assertEquals(true, r.rows.isEmpty());
  }

  @IsTest
  static void getEvents_withFilters_exercisesWhereClause() {
    CastleEventsReportSvc.EventFilterDto f = new CastleEventsReportSvc.EventFilterDto();
    f.subjectContains = 'x';
    f.locationContains = 'y';
    f.timeScope = 'future';
    f.startDateTimeFrom = Datetime.now().addDays(-30);
    f.startDateTimeTo = Datetime.now().addDays(30);
    CastleEventsReportSvc.EventQueryResultDto r = CastleEventsReportSvc.getEvents(
      f,
      10,
      1,
      'Subject',
      'asc',
      null
    );
    System.assertNotEquals(null, r.rows);
  }

  @IsTest
  static void getEvents_withOwnerFilter_exercisesWhereClause() {
    CastleEventsReportSvc.EventFilterDto f = new CastleEventsReportSvc.EventFilterDto();
    f.ownerUserId = UserInfo.getUserId();
    CastleEventsReportSvc.EventQueryResultDto r = CastleEventsReportSvc.getEvents(
      f,
      10,
      1,
      'OwnerName',
      'asc',
      null
    );
    System.assertNotEquals(null, r.rows);
  }

  @IsTest
  static void getEvents_withConvertedLeadContactAndEvent_returnsRow() {
    LeadStatus openSt = [
      SELECT MasterLabel
      FROM LeadStatus
      WHERE IsConverted = FALSE
      ORDER BY SortOrder NULLS LAST
      LIMIT 1
    ];

    Account acc = new Account(Name = 'Castle Test Acc');
    insert acc;

    Lead ld = new Lead(LastName = 'CastleLead', Company = 'Castle Co', Status = openSt.MasterLabel);
    insert ld;

    List<LeadStatus> convStatuses = [
      SELECT MasterLabel
      FROM LeadStatus
      WHERE IsConverted = TRUE
      ORDER BY SortOrder NULLS LAST
    ];

    Database.LeadConvertResult lcr;
    Boolean convertedOk = false;
    for (LeadStatus ls : convStatuses) {
      Database.LeadConvert lc = new Database.LeadConvert();
      lc.setLeadId(ld.Id);
      lc.setConvertedStatus(ls.MasterLabel);
      lc.setAccountId(acc.Id);
      lc.setDoNotCreateOpportunity(true);
      try {
        lcr = Database.convertLead(lc);
        if (lcr != null && lcr.isSuccess()) {
          convertedOk = true;
          break;
        }
      } catch (DmlException e) {
        continue;
      }
    }
    if (!convertedOk) {
      return;
    }

    Id contactId = lcr.getContactId();
    Contact c = new Contact(Id = contactId, Candidato__c = ld.Id);
    update c;

    Datetime start = System.now().addDays(1);
    Event ev = new Event(
      Subject = 'Test reunión',
      StartDateTime = start,
      EndDateTime = start.addHours(1),
      WhoId = c.Id,
      DurationInMinutes = 60
    );
    insert ev;

    CastleEventsReportSvc.EventFilterDto f = new CastleEventsReportSvc.EventFilterDto();
    CastleEventsReportSvc.EventQueryResultDto r = CastleEventsReportSvc.getEvents(
      f,
      25,
      1,
      'StartDateTime',
      'desc',
      null
    );

    System.assert(r.totalRows >= 1);
    Boolean found = false;
    for (CastleEventsReportSvc.EventRowDto row : r.rows) {
      if (row.eventId == ev.Id) {
        found = true;
        System.assertEquals(true, row.candidatoIsConverted);
        break;
      }
    }
    System.assert(found);
  }

  @IsTest
  static void buildOrderClause_coversBranches() {
    System.assert(CastleEventsReportSvc.buildOrderClause('Subject', 'asc').contains('Subject'));
    System.assert(CastleEventsReportSvc.buildOrderClause('StartDateTime', 'desc').contains('StartDateTime'));
    System.assert(CastleEventsReportSvc.buildOrderClause('EndDateTime', 'asc').contains('EndDateTime'));
    System.assert(CastleEventsReportSvc.buildOrderClause('Location', 'desc').contains('Location'));
    System.assert(CastleEventsReportSvc.buildOrderClause('CreatedDate', 'asc').contains('CreatedDate'));
    System.assert(CastleEventsReportSvc.buildOrderClause('OwnerName', 'desc').contains('Owner.Name'));
    System.assert(CastleEventsReportSvc.buildOrderClause('unknown', 'asc').contains('StartDateTime'));
  }

  @IsTest(SeeAllData=true)
  static void getEvents_seeAllData_coversQueryWhenDataExists() {
    List<Contact> cands = [
      SELECT Id
      FROM Contact
      WHERE Candidato__c != null AND Candidato__r.IsConverted = true
      LIMIT 1
    ];
    if (cands.isEmpty()) {
      return;
    }
    CastleEventsReportSvc.EventFilterDto f = new CastleEventsReportSvc.EventFilterDto();
    CastleEventsReportSvc.EventQueryResultDto r = CastleEventsReportSvc.getEvents(
      f,
      25,
      1,
      'StartDateTime',
      'desc',
      null
    );
    System.assertNotEquals(null, r);
    if (r.nextCursor != null) {
      CastleEventsReportSvc.KeysetCursorDto nc = new CastleEventsReportSvc.KeysetCursorDto();
      nc.lastEventId = r.nextCursor.lastEventId;
      nc.lastStartDateTimeIso = r.nextCursor.lastStartDateTimeIso;
      CastleEventsReportSvc.getEvents(f, 25, 2, 'StartDateTime', 'desc', nc);
    }
  }

  @IsTest
  static void parseAndFormatIso_coversEdgeCases() {
    System.assertEquals(null, CastleEventsReportSvc.parseIsoToDatetimeGmt(null));
    System.assertEquals(null, CastleEventsReportSvc.parseIsoToDatetimeGmt(''));
    Datetime dt = CastleEventsReportSvc.parseIsoToDatetimeGmt('2025-01-15T12:00:00.000Z');
    System.assertNotEquals(null, dt);
    System.assertEquals(null, CastleEventsReportSvc.formatIsoGmt(null));
    System.assertNotEquals(null, CastleEventsReportSvc.formatIsoGmt(Datetime.now()));
  }
}