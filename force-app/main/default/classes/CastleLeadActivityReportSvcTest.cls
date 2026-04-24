@IsTest
public class CastleLeadActivityReportSvcTest {
  private static final String CONV_FIELD = 'Fecha_Conversi_n_MKT__c';
  /** CUIT de prueba (11 dígitos) si la org valida CUIT__c en Lead. */
  private static final Decimal TEST_CUIT = Decimal.valueOf('20123456789');

  private static void assertConversionField() {
    System.assert(
      Lead.SObjectType.getDescribe().fields.getMap().containsKey(CONV_FIELD),
      'La org de tests debe tener Lead.' + CONV_FIELD
    );
  }

  /** Primera opción activa de un picklist de causa/motivo no cualificado (validaciones por org). */
  public static void fillNoCualificadoPicklists(Lead ld) {
    Map<String, Schema.SObjectField> fm = Lead.SObjectType.getDescribe().fields.getMap();
    List<String> keys = new List<String>(fm.keySet());
    keys.sort();
    for (String key : keys) {
      String kl = key.toLowerCase();
      if (!(kl.contains('cualif') || kl.contains('cualificado'))) {
        continue;
      }
      if (!(kl.contains('causa') || kl.contains('motivo') || kl.contains('mql'))) {
        continue;
      }
      Schema.DescribeFieldResult fr = fm.get(key).getDescribe();
      if (fr.getType() != Schema.DisplayType.Picklist) {
        continue;
      }
      for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
        if (pe.isActive() && String.isNotBlank(pe.getValue())) {
          ld.put(key, pe.getValue());
          return;
        }
      }
    }
    for (String key : keys) {
      Schema.DescribeFieldResult fr = fm.get(key).getDescribe();
      if (fr.getType() != Schema.DisplayType.Picklist) {
        continue;
      }
      String lab = fr.getLabel() != null ? fr.getLabel().toLowerCase() : '';
      if (!(lab.contains('causa') && lab.contains('cualif'))) {
        continue;
      }
      for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
        if (pe.isActive() && String.isNotBlank(pe.getValue())) {
          ld.put(fr.getName(), pe.getValue());
          return;
        }
      }
    }
    for (String key : keys) {
      Schema.DescribeFieldResult fr = fm.get(key).getDescribe();
      if (fr.getType() != Schema.DisplayType.Picklist) {
        continue;
      }
      String lab = fr.getLabel() != null ? fr.getLabel().toLowerCase() : '';
      if (!lab.contains('causa')) {
        continue;
      }
      for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
        if (pe.isActive() && String.isNotBlank(pe.getValue())) {
          ld.put(fr.getName(), pe.getValue());
          return;
        }
      }
    }
    for (String key : keys) {
      Schema.DescribeFieldResult fr = fm.get(key).getDescribe();
      Schema.DisplayType t = fr.getType();
      if (t != Schema.DisplayType.String && t != Schema.DisplayType.TextArea) {
        continue;
      }
      String lab = fr.getLabel() != null ? fr.getLabel().toLowerCase() : '';
      if (lab.contains('causa') && (lab.contains('cualif') || lab.contains('no cual'))) {
        ld.put(fr.getName(), 'Test automático');
        return;
      }
    }
  }

  private static LeadStatus pickNoCualificadoStatus() {
    List<LeadStatus> st = [
      SELECT MasterLabel
      FROM LeadStatus
      WHERE IsConverted = FALSE AND MasterLabel = 'No Cualificado'
      LIMIT 1
    ];
    System.assert(!st.isEmpty(), 'Se requiere LeadStatus con etiqueta No Cualificado para tests.');
    return st[0];
  }

  /** Lead en universo del reporte: No Cualificado con Fecha_Conversi_n_MKT__c. */
  private static Lead newLeadUniverse(Date convDate) {
    LeadStatus st = pickNoCualificadoStatus();
    Lead ld = new Lead(LastName = 'SvcTest', Company = 'Co', Status = st.MasterLabel);
    ld.put(CONV_FIELD, convDate);
    if (Lead.SObjectType.getDescribe().fields.getMap().containsKey('CUIT__c')) {
      ld.put('CUIT__c', TEST_CUIT);
    }
    if (Lead.SObjectType.getDescribe().fields.getMap().containsKey('MQL_Comentario__c')) {
      ld.put('MQL_Comentario__c', 'Test automático');
    }
    fillNoCualificadoPicklists(ld);
    return ld;
  }

  @IsTest
  static void getReport_empty_returnsZeros() {
    CastleLeadActivityReportSvc.ActivityFilterDto f = new CastleLeadActivityReportSvc.ActivityFilterDto();
    CastleLeadActivityReportSvc.ReportResultDto r = CastleLeadActivityReportSvc.getReport(f);
    System.assertEquals(0, r.ownerRowCount);
    System.assertNotEquals(null, r.rows);
    System.assertEquals(0, r.leadPoolCount);
  }

  @IsTest
  static void getReport_countsLeadWho_tasksWithPrefix_and_eventsInWindow() {
    assertConversionField();

    Lead ld = newLeadUniverse(Date.today());
    insert ld;
    Test.setCreatedDate(ld.Id, Datetime.now().addDays(-3));

    Datetime startEv = Datetime.newInstanceGmt(Date.today(), Time.newInstance(12, 0, 0, 0));
    Event ev = new Event(
      Subject = 'Reunión lead',
      StartDateTime = startEv,
      EndDateTime = startEv.addHours(1),
      WhoId = ld.Id,
      DurationInMinutes = 60
    );
    insert ev;

    Task tkOk = new Task(
      Subject = 'R - Llamada lead',
      WhoId = ld.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
    insert tkOk;

    Task tkT = new Task(
      Subject = 'T - Otra tarea',
      WhoId = ld.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
    insert tkT;

    Task tkNo = new Task(
      Subject = 'Sin prefijo',
      WhoId = ld.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
    insert tkNo;

    CastleLeadActivityReportSvc.treatAsConvertedLeadIdsInTest = new Set<Id>{ ld.Id };

    CastleLeadActivityReportSvc.ActivityFilterDto f = new CastleLeadActivityReportSvc.ActivityFilterDto();
    CastleLeadActivityReportSvc.ReportResultDto r = CastleLeadActivityReportSvc.getReport(f);

    System.assertEquals(1, r.leadPoolCount, 'Un lead en universo (filtro)');
    System.assertEquals(1, r.convertedLeadCount, 'Marcado como convertido en test');
    System.assert(r.sumTotalEvents >= 1, 'Evento en ventana (KPI = actividad en convertidos)');
    System.assertEquals(2, r.sumTotalTasks, 'Cuenta tareas R - y T - ');
    System.assert(r.ownerRowCount >= 1);
    System.assertEquals(1, r.rows.size(), 'Una fila por lead convertido');
    CastleLeadActivityReportSvc.OwnerLeadRowDto d0 = r.rows[0];
    Lead ldRef = [SELECT OwnerId FROM Lead WHERE Id = :ld.Id LIMIT 1];
    System.assertEquals(String.valueOf(ldRef.OwnerId), d0.ownerId, 'Columna propietario = Lead.OwnerId');
    System.assertEquals(String.valueOf(ld.Id), d0.leadId);
    System.assert(d0.showOwnerCell == true);
    System.assertEquals(1, d0.ownerRowSpan);
    System.assert(d0.leadIsConverted == true);
    System.assert(d0.totalEvents >= 1);
    System.assert(d0.totalTasks >= 2);
    System.assert(d0.relatedContacts != null && d0.relatedContacts.isEmpty(), 'Sin Candidato__c');
    System.assert(String.isNotBlank(d0.leadCreatedDateStr), 'Fecha creación lead');
    System.assert(String.isNotBlank(d0.leadConversionDateStr), 'Fecha ref. conversión');
    System.assertEquals(Decimal.valueOf('2.00'), r.avgTasksPerLead);
    System.assertEquals(Decimal.valueOf('1.00'), r.avgEventsPerLead);
  }

  @IsTest
  static void getReport_unifiesContactCandidato() {
    assertConversionField();

    Account acc = new Account(Name = 'Acc Candidato');
    insert acc;

    Lead ld = newLeadUniverse(Date.today());
    insert ld;
    Test.setCreatedDate(ld.Id, Datetime.now().addDays(-5));

    Contact c = new Contact(LastName = 'Cont', AccountId = acc.Id, Candidato__c = ld.Id);
    insert c;

    Task tk = new Task(
      Subject = 'R - Tarea contacto',
      WhoId = c.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
    insert tk;

    Datetime startEv = Datetime.newInstanceGmt(Date.today(), Time.newInstance(15, 0, 0, 0));
    Event ev = new Event(
      Subject = 'Evt contacto',
      StartDateTime = startEv,
      EndDateTime = startEv.addHours(1),
      WhoId = c.Id,
      DurationInMinutes = 60
    );
    insert ev;

    CastleLeadActivityReportSvc.treatAsConvertedLeadIdsInTest = new Set<Id>{ ld.Id };

    CastleLeadActivityReportSvc.ActivityFilterDto f = new CastleLeadActivityReportSvc.ActivityFilterDto();
    CastleLeadActivityReportSvc.ReportResultDto r = CastleLeadActivityReportSvc.getReport(f);

    System.assertEquals(1, r.leadPoolCount);
    System.assertEquals(1, r.convertedLeadCount);
    System.assert(r.sumTotalEvents >= 1);
    System.assert(r.sumTotalTasks >= 1);
    System.assertEquals(Decimal.valueOf('1.00'), r.avgTasksPerLead);
    System.assertEquals(Decimal.valueOf('1.00'), r.avgEventsPerLead);
    CastleLeadActivityReportSvc.OwnerLeadRowDto dr = r.rows[0];
    System.assert(dr.relatedContacts != null && dr.relatedContacts.size() == 1);
    System.assertEquals(String.valueOf(c.Id), dr.relatedContacts[0].contactId);
  }

  @IsTest
  static void getReport_excludesTaskBeforeLeadCreation() {
    assertConversionField();

    Date conv = Date.today().addDays(90);
    Lead ld = newLeadUniverse(conv);
    insert ld;
    Test.setCreatedDate(ld.Id, Datetime.now());

    Task tk = new Task(
      Subject = 'R - Antes de creación lead',
      WhoId = ld.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today().addDays(-15)
    );
    insert tk;

    CastleLeadActivityReportSvc.ActivityFilterDto f = new CastleLeadActivityReportSvc.ActivityFilterDto();
    CastleLeadActivityReportSvc.ReportResultDto r = CastleLeadActivityReportSvc.getReport(f);

    System.assertEquals(0, r.sumTotalTasks, 'Tarea con fecha anterior a CreatedDate del lead no cuenta');
    System.assertEquals(0, r.convertedLeadCount);
    System.assertEquals(0, r.rows.size(), 'Lead abierto: no filas en tabla');
  }

  @IsTest
  static void getReport_excludesActivityOutsideWindow() {
    assertConversionField();

    Date conv = Date.today().addDays(-10);
    Lead ld = newLeadUniverse(conv);
    insert ld;
    Test.setCreatedDate(ld.Id, Datetime.now().addDays(-20));

    Task tkLate = new Task(
      Subject = 'R - Fuera de ventana',
      WhoId = ld.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
    insert tkLate;

    CastleLeadActivityReportSvc.ActivityFilterDto f = new CastleLeadActivityReportSvc.ActivityFilterDto();
    CastleLeadActivityReportSvc.ReportResultDto r = CastleLeadActivityReportSvc.getReport(f);

    System.assertEquals(1, r.leadPoolCount);
    System.assertEquals(0, r.convertedLeadCount);
    System.assertEquals(0, r.rows.size());
    System.assertEquals(0, r.sumTotalTasks, 'ActivityDate posterior a conversión no cuenta');
  }

  @IsTest
  static void effectiveReferenceDate_noCualificado_fromQuery() {
    assertConversionField();
    Lead ld = newLeadUniverse(Date.today().addDays(2));
    insert ld;
    Lead rq = [
      SELECT IsConverted, Status, Fecha_Conversi_n_MKT__c, ConvertedDate
      FROM Lead
      WHERE Id = :ld.Id
    ];
    Date d = CastleLeadActivityReportSvc.effectiveReferenceDateForTest(rq);
    System.assertEquals(Date.today().addDays(2), d);
  }

  @IsTest
  static void getReport_withOwnerFilter() {
    assertConversionField();
    Lead ld = newLeadUniverse(Date.today());
    insert ld;
    Test.setCreatedDate(ld.Id, Datetime.now().addDays(-1));
    Task tk = new Task(
      Subject = 'R - Owner filter',
      WhoId = ld.Id,
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
    insert tk;
    CastleLeadActivityReportSvc.treatAsConvertedLeadIdsInTest = new Set<Id>{ ld.Id };
    CastleLeadActivityReportSvc.ActivityFilterDto f = new CastleLeadActivityReportSvc.ActivityFilterDto();
    f.ownerUserId = UserInfo.getUserId();
    CastleLeadActivityReportSvc.ReportResultDto r = CastleLeadActivityReportSvc.getReport(f);
    System.assertEquals(1, r.leadPoolCount);
    System.assertEquals(1, r.convertedLeadCount);
    System.assertEquals(1, r.rows.size());
    System.assert(r.sumTotalTasks >= 1);
  }

  @IsTest
  static void getReport_futureDateRange_emptyUniverse() {
    assertConversionField();
    CastleLeadActivityReportSvc.ActivityFilterDto f = new CastleLeadActivityReportSvc.ActivityFilterDto();
    f.conversionDateFrom = Date.newInstance(2099, 1, 1);
    f.conversionDateTo = Date.newInstance(2099, 12, 31);
    CastleLeadActivityReportSvc.ReportResultDto r = CastleLeadActivityReportSvc.getReport(f);
    System.assertEquals(0, r.leadPoolCount);
    System.assertEquals(0, r.convertedLeadCount);
    System.assertEquals(0, r.sumTotalEvents);
    System.assertEquals(0, r.sumTotalTasks);
    System.assertEquals(0, r.sumTotalEmails);
  }

  @IsTest
  static void applyEmailMessagesToLeadAgg_countsInMemoryOutbound() {
    assertConversionField();
    Lead ld = newLeadUniverse(Date.today());
    insert ld;
    Test.setCreatedDate(ld.Id, Datetime.now().addDays(-2));
    Lead ldFull = [
      SELECT Id, Name, OwnerId, CreatedDate, IsConverted, Status, ConvertedDate, Fecha_Conversi_n_MKT__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    Map<Id, Lead> leadMap = new Map<Id, Lead>{ ldFull.Id => ldFull };
    EmailMessage em = new EmailMessage();
    em.RelatedToId = ld.Id;
    em.MessageDate = Datetime.newInstanceGmt(Date.today(), Time.newInstance(10, 0, 0, 0));
    em.Incoming = false;
    em.Status = '3';
    Integer n = CastleLeadActivityReportSvc.applyEmailMessagesToLeadAggCountForTest(
      new List<EmailMessage>{ em },
      leadMap,
      new Map<Id, Id>()
    );
    System.assertEquals(1, n);
  }
}