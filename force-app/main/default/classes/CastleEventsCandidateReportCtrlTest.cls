@IsTest
private class CastleEventsCandidateReportCtrlTest {
  private static final String CONV_FIELD = 'Fecha_Conversi_n_MKT__c';
  private static final Decimal TEST_CUIT = Decimal.valueOf('20123456789');

  @IsTest
  static void getLeadActivityReport_delegates_withRows() {
    System.assert(
      Lead.SObjectType.getDescribe().fields.getMap().containsKey(CONV_FIELD),
      'La org de tests debe tener Lead.' + CONV_FIELD
    );
    List<LeadStatus> stNc = [
      SELECT MasterLabel
      FROM LeadStatus
      WHERE IsConverted = FALSE AND MasterLabel = 'No Cualificado'
      LIMIT 1
    ];
    System.assert(!stNc.isEmpty(), 'Se requiere estado No Cualificado para el test.');
    Lead ld = new Lead(LastName = 'CtrlLead', Company = 'Co', Status = stNc[0].MasterLabel);
    ld.put(CONV_FIELD, Date.today());
    if (Lead.SObjectType.getDescribe().fields.getMap().containsKey('CUIT__c')) {
      ld.put('CUIT__c', TEST_CUIT);
    }
    if (Lead.SObjectType.getDescribe().fields.getMap().containsKey('MQL_Comentario__c')) {
      ld.put('MQL_Comentario__c', 'Test automático');
    }
    CastleLeadActivityReportSvcTest.fillNoCualificadoPicklists(ld);
    insert ld;
    Test.setCreatedDate(ld.Id, Datetime.now().addDays(-2));

    Datetime startEv = Datetime.newInstanceGmt(Date.today(), Time.newInstance(9, 0, 0, 0));
    Event ev = new Event(
      Subject = 'Ctrl ev',
      StartDateTime = startEv,
      EndDateTime = startEv.addHours(1),
      WhoId = ld.Id,
      DurationInMinutes = 60
    );
    insert ev;

    Task tk = new Task(
      Subject = 'R - Ctrl task',
      WhoId = ld.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
    insert tk;

    CastleLeadActivityReportSvc.treatAsConvertedLeadIdsInTest = new Set<Id>{ ld.Id };

    CastleEventsCandidateReportController.ActivityFilterDto f = new CastleEventsCandidateReportController.ActivityFilterDto();
    CastleEventsCandidateReportController.ReportResultDto r = CastleEventsCandidateReportController.getLeadActivityReport(f);
    System.assertNotEquals(null, r);
    System.assertNotEquals(null, r.rows);
    System.assert(r.ownerRowCount >= 1);
    System.assert(r.sumTotalEvents >= 1);
    System.assert(r.sumTotalTasks >= 1);
  }

  @IsTest
  static void getLeadActivityReport_nullFilter_coversToSvc() {
    CastleEventsCandidateReportController.ReportResultDto r = CastleEventsCandidateReportController.getLeadActivityReport(null);
    System.assertNotEquals(null, r);
    System.assertNotEquals(null, r.rows);
  }
}