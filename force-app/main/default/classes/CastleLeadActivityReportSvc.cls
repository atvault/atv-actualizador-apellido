/**
 * Actividades agregadas por lead. Columna propietario = Lead.OwnerId (no Owner de tarea/evento).
 * Universo consulta: convertidos o No Cualificado con MKT. Filtro opcional por Lead.OwnerId.
 * Tabla y KPIs: solo leads convertidos en ese alcance (una fila aunque no tengan actividad).
 * Ventana actividad: CreatedDate del lead → fecha ref. (ConvertedDate o MKT). Tareas R - / T - .
 * Emails: EmailMessage saliente (Incoming=false) no borrador, RelatedToId = Lead o Contact (Candidato).
 * Contact=Candidato__c unificado al lead.
 */
public with sharing class CastleLeadActivityReportSvc {
  private static final String TASK_SUBJECT_PREFIX_R = 'R - ';
  private static final String TASK_SUBJECT_PREFIX_T = 'T - ';
  /** API name: fecha conversión MKT (No Cualificado). */
  private static final String LEAD_CONVERSION_FIELD = 'Fecha_Conversi_n_MKT__c';
  /** Valor de Lead.Status (etiqueta/API) para usar Fecha_Conversi_n_MKT__c. */
  private static final String LEAD_STATUS_NO_CUALIFICADO = 'No Cualificado';

  /**
   * Solo tests: Ids a tratar como convertidos (tabla, KPIs, columna) sin usar Database.convertLead.
   * En producción no se usa. Necesario cuando la org exige datos/reglas imposibles de armar en test.
   */
  @TestVisible
  private static Set<Id> treatAsConvertedLeadIdsInTest;

  public class ActivityFilterDto {
    /** Filtro: conversión del lead desde (fecha, sin hora). */
    public Date conversionDateFrom { get; set; }
    /** Filtro: conversión del lead hasta (fecha inclusive). */
    public Date conversionDateTo { get; set; }
    /** Filtro: Lead.OwnerId (propietario del lead, no de la actividad). */
    public Id ownerUserId { get; set; }
  }

  /** Contacto con lookup Candidato__c → Lead del universo. */
  public class RelatedContactDto {
    public String contactId { get; set; }
    public String contactName { get; set; }
    public String contactUrl { get; set; }
  }

  /**
   * Una fila de detalle: totales de actividad por lead; owner* = Lead.OwnerId.
   */
  public class OwnerLeadRowDto {
    public String rowKey { get; set; }
    public String ownerId { get; set; }
    public String ownerName { get; set; }
    public String ownerUrl { get; set; }
    public Boolean showOwnerCell { get; set; }
    public Integer ownerRowSpan { get; set; }
    public String leadId { get; set; }
    public String leadName { get; set; }
    public String leadUrl { get; set; }
    /** Fecha creación del lead (solo día, GMT), yyyy-MM-dd. */
    public String leadCreatedDateStr { get; set; }
    /** Fecha de referencia (ConvertedDate o MKT según reglas), yyyy-MM-dd. */
    public String leadConversionDateStr { get; set; }
    /** Lead.IsConverted (convertido vs abierto ej. No Cualificado). */
    public Boolean leadIsConverted { get; set; }
    /** Contactos donde Candidato__c = este lead (puede haber más de uno). */
    public List<RelatedContactDto> relatedContacts { get; set; }
    public Integer totalEvents { get; set; }
    public Integer totalTasks { get; set; }
    /** EmailMessage salientes en ventana (Lead o Contact relacionado). */
    public Integer totalEmails { get; set; }
  }

  public class ReportResultDto {
    public List<OwnerLeadRowDto> rows { get; set; }
    /** Suma global de eventos (lead + contact unificado). */
    public Integer sumTotalEvents { get; set; }
    /** Suma global de tareas (lead + contact, prefijos R - y T - ). */
    public Integer sumTotalTasks { get; set; }
    /** Suma global de emails salientes (EmailMessage) en filas del reporte. */
    public Integer sumTotalEmails { get; set; }
    /**
     * Leads en el filtro (fecha ref. + propietario opcional): total universo consultado
     * (convertidos + No Cualificado con MKT). Para KPIs ver convertedLeadCount y filas.
     */
    public Integer leadPoolCount { get; set; }
    /** Leads convertidos (IsConverted) en ese mismo filtro; mismas filas que la tabla. */
    public Integer convertedLeadCount { get; set; }
    public Decimal avgTasksPerLead { get; set; }
    public Decimal avgEventsPerLead { get; set; }
    public Decimal avgEmailsPerLead { get; set; }
    /** Cantidad de Lead.OwnerId distintos entre filas de la tabla (leads convertidos). */
    public Integer ownerRowCount { get; set; }
  }

  private class OwnerLeadAgg {
    Integer totalEvents = 0;
    Integer totalTasks = 0;
    Integer totalEmails = 0;
  }

  public static ReportResultDto getReport(ActivityFilterDto filters) {
    assertCanRead();

    ReportResultDto out = new ReportResultDto();
    out.rows = new List<OwnerLeadRowDto>();
    out.sumTotalEvents = 0;
    out.sumTotalTasks = 0;
    out.sumTotalEmails = 0;
    out.leadPoolCount = 0;
    out.convertedLeadCount = 0;
    out.avgTasksPerLead = null;
    out.avgEventsPerLead = null;
    out.avgEmailsPerLead = null;
    out.ownerRowCount = 0;

    Date convFrom = filters != null ? filters.conversionDateFrom : null;
    Date convTo = filters != null ? filters.conversionDateTo : null;
    Id ownerId = filters != null ? filters.ownerUserId : null;

    String nc = LEAD_STATUS_NO_CUALIFICADO;
    String leadSoql =
      'SELECT Id, Name, OwnerId, CreatedDate, IsConverted, Status, ConvertedDate, ' +
      LEAD_CONVERSION_FIELD +
      ' FROM Lead WHERE IsConverted = true OR (Status = :nc AND ' +
      LEAD_CONVERSION_FIELD +
      ' != null)';

    List<Lead> leadRowsRaw;
    try {
      leadRowsRaw = Database.query(leadSoql);
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'No se pudo leer leads (¿existe el campo ' +
        LEAD_CONVERSION_FIELD +
        '?). ' +
        qe.getMessage()
      );
    }

    List<Lead> leadRows = new List<Lead>();
    for (Lead ld : leadRowsRaw) {
      Date ref = effectiveReferenceDate(ld);
      if (ref == null) {
        continue;
      }
      if (convFrom != null && ref < convFrom) {
        continue;
      }
      if (convTo != null && ref > convTo) {
        continue;
      }
      leadRows.add(ld);
    }

    if (leadRows.isEmpty()) {
      return out;
    }

    Map<Id, Lead> leadMap = new Map<Id, Lead>(leadRows);
    Set<Id> leadIds = leadMap.keySet();

    List<Lead> scopedLeads = new List<Lead>();
    for (Lead ld : leadRows) {
      if (ownerId != null && ld.OwnerId != ownerId) {
        continue;
      }
      scopedLeads.add(ld);
    }
    out.leadPoolCount = scopedLeads.size();
    Integer convCt = 0;
    for (Lead lx : scopedLeads) {
      if (isConvertedForReportRow(lx)) {
        convCt++;
      }
    }
    out.convertedLeadCount = convCt;

    Map<Id, Id> contactIdToLeadId = new Map<Id, Id>();
    Map<Id, List<Contact>> leadIdToContacts = new Map<Id, List<Contact>>();
    for (Contact c : [
      SELECT Id, Name, Candidato__c
      FROM Contact
      WHERE Candidato__c IN :leadIds AND Candidato__c != NULL
    ]) {
      contactIdToLeadId.put(c.Id, c.Candidato__c);
      if (!leadIdToContacts.containsKey(c.Candidato__c)) {
        leadIdToContacts.put(c.Candidato__c, new List<Contact>());
      }
      leadIdToContacts.get(c.Candidato__c).add(c);
    }

    Set<Id> whoIds = new Set<Id>();
    whoIds.addAll(leadIds);
    whoIds.addAll(contactIdToLeadId.keySet());

    String taskLikeR = TASK_SUBJECT_PREFIX_R + '%';
    String taskLikeT = TASK_SUBJECT_PREFIX_T + '%';

    Set<Id> emailRelatedIds = new Set<Id>();
    emailRelatedIds.addAll(leadIds);
    emailRelatedIds.addAll(contactIdToLeadId.keySet());

    List<Task> tasks;
    List<Event> events;
    List<EmailMessage> emailMsgs = new List<EmailMessage>();
    try {
      tasks = Database.query(
        'SELECT WhoId, ActivityDate, CompletedDateTime FROM Task WHERE WhoId IN :whoIds AND (Subject LIKE :taskLikeR OR Subject LIKE :taskLikeT) '
      );
      events = Database.query(
        'SELECT WhoId, StartDateTime FROM Event WHERE WhoId IN :whoIds '
      );
      if (!emailRelatedIds.isEmpty()) {
        emailMsgs = [
          SELECT RelatedToId, MessageDate, Incoming, Status
          FROM EmailMessage
          WHERE
            RelatedToId IN :emailRelatedIds
            AND Incoming = false
            AND MessageDate != NULL
            AND (Status = NULL
            OR Status != '5')
        ];
      }
    } catch (QueryException qe) {
      throw new AuraHandledException('No se pudo leer tareas/eventos/emails: ' + qe.getMessage());
    }

    Map<Id, OwnerLeadAgg> byLead = new Map<Id, OwnerLeadAgg>();

    for (Task t : tasks) {
      if (t.WhoId == null) {
        continue;
      }
      Date taskAct = taskEffectiveActivityDate(t);
      if (taskAct == null) {
        continue;
      }
      Id leadCanon = canonicalLeadId(t.WhoId, leadMap.keySet(), contactIdToLeadId);
      if (leadCanon == null) {
        continue;
      }
      Lead wfLd = leadMap.get(leadCanon);
      if (!activityDateInLeadWindow(taskAct, wfLd, leadMap)) {
        continue;
      }
      addTaskToLead(byLead, leadCanon);
    }

    for (Event ev : events) {
      if (ev.WhoId == null || ev.StartDateTime == null) {
        continue;
      }
      Id leadCanon = canonicalLeadId(ev.WhoId, leadMap.keySet(), contactIdToLeadId);
      if (leadCanon == null) {
        continue;
      }
      Lead wfLd = leadMap.get(leadCanon);
      if (!eventStartInLeadWindow(ev.StartDateTime, wfLd, leadMap)) {
        continue;
      }
      addEventToLead(byLead, leadCanon);
    }

    applyEmailMessagesToLeadAgg(emailMsgs, leadMap, contactIdToLeadId, byLead);

    List<Id> tableLeadIds = new List<Id>();
    for (Lead ld : scopedLeads) {
      if (!isConvertedForReportRow(ld)) {
        continue;
      }
      tableLeadIds.add(ld.Id);
    }

    Set<Id> tableOwnerIds = new Set<Id>();
    for (Lead ld : scopedLeads) {
      if (isConvertedForReportRow(ld) && ld.OwnerId != null) {
        tableOwnerIds.add(ld.OwnerId);
      }
    }
    Map<Id, String> ownerNames = resolveOwnerDisplayNames(tableOwnerIds);

    tableLeadIds.sort(new LeadIdByLeadOwnerComparator(leadMap, ownerNames));

    List<OwnerLeadRowDto> flatRows = new List<OwnerLeadRowDto>();
    Set<Id> ownerIdsDistinct = new Set<Id>();
    for (Id lid : tableLeadIds) {
      OwnerLeadAgg ag = byLead.get(lid);
      Lead ldRow = leadMap.get(lid);
      Id ow = ldRow != null ? ldRow.OwnerId : null;
      String lname = ldRow != null && ldRow.Name != null ? ldRow.Name : '';
      OwnerLeadRowDto row = new OwnerLeadRowDto();
      row.rowKey = (ow != null ? String.valueOf(ow) : 'x') + '_' + String.valueOf(lid);
      row.ownerId = ow != null ? String.valueOf(ow) : '';
      row.ownerUrl = ow != null ? '/' + ow : '';
      row.ownerName = ow != null && ownerNames.containsKey(ow) ? ownerNames.get(ow) : '';
      row.leadId = String.valueOf(lid);
      row.leadUrl = '/' + lid;
      row.leadName = lname;
      if (ldRow != null) {
        row.leadCreatedDateStr = dateToIso(ldRow.CreatedDate.dateGMT());
        row.leadConversionDateStr = dateToIso(effectiveReferenceDate(ldRow));
        row.leadIsConverted = isConvertedForReportRow(ldRow);
      } else {
        row.leadCreatedDateStr = '';
        row.leadConversionDateStr = '';
        row.leadIsConverted = false;
      }
      row.totalEvents = ag != null ? ag.totalEvents : 0;
      row.totalTasks = ag != null ? ag.totalTasks : 0;
      row.totalEmails = ag != null ? ag.totalEmails : 0;
      row.showOwnerCell = true;
      row.ownerRowSpan = 1;
      row.relatedContacts = buildRelatedContactsForLead(lid, leadIdToContacts);
      if (ow != null) {
        ownerIdsDistinct.add(ow);
      }
      flatRows.add(row);
    }

    for (OwnerLeadRowDto r : flatRows) {
      out.sumTotalEvents += nz(r.totalEvents);
      out.sumTotalTasks += nz(r.totalTasks);
      out.sumTotalEmails += nz(r.totalEmails);
    }
    out.rows = flatRows;
    out.ownerRowCount = ownerIdsDistinct.size();

    if (out.convertedLeadCount > 0) {
      out.avgTasksPerLead = Decimal.valueOf(out.sumTotalTasks)
        .divide(Decimal.valueOf(out.convertedLeadCount), 2);
      out.avgEventsPerLead = Decimal.valueOf(out.sumTotalEvents)
        .divide(Decimal.valueOf(out.convertedLeadCount), 2);
      out.avgEmailsPerLead = Decimal.valueOf(out.sumTotalEmails)
        .divide(Decimal.valueOf(out.convertedLeadCount), 2);
    }

    return out;
  }

  private static Boolean isConvertedForReportRow(Lead ld) {
    if (ld == null) {
      return false;
    }
    if (ld.IsConverted == true) {
      return true;
    }
    return Test.isRunningTest() &&
      treatAsConvertedLeadIdsInTest != null &&
      treatAsConvertedLeadIdsInTest.contains(ld.Id);
  }

  private static Id canonicalLeadId(
    Id whoId,
    Set<Id> leadIds,
    Map<Id, Id> contactIdToLeadId
  ) {
    if (whoId.getSObjectType() == Lead.SObjectType && leadIds.contains(whoId)) {
      return whoId;
    }
    if (whoId.getSObjectType() == Contact.SObjectType && contactIdToLeadId.containsKey(whoId)) {
      return contactIdToLeadId.get(whoId);
    }
    return null;
  }

  private static void addTaskToLead(Map<Id, OwnerLeadAgg> byLead, Id leadCanon) {
    if (!byLead.containsKey(leadCanon)) {
      byLead.put(leadCanon, new OwnerLeadAgg());
    }
    byLead.get(leadCanon).totalTasks++;
  }

  private static void addEventToLead(Map<Id, OwnerLeadAgg> byLead, Id leadCanon) {
    if (!byLead.containsKey(leadCanon)) {
      byLead.put(leadCanon, new OwnerLeadAgg());
    }
    byLead.get(leadCanon).totalEvents++;
  }

  private static void addEmailToLead(Map<Id, OwnerLeadAgg> byLead, Id leadCanon) {
    if (!byLead.containsKey(leadCanon)) {
      byLead.put(leadCanon, new OwnerLeadAgg());
    }
    byLead.get(leadCanon).totalEmails++;
  }

  /** Contabiliza EmailMessage ya cargados; extraído para tests con filas en memoria (sin DML). */
  private static void applyEmailMessagesToLeadAgg(
    List<EmailMessage> emailMsgs,
    Map<Id, Lead> leadMap,
    Map<Id, Id> contactIdToLeadId,
    Map<Id, OwnerLeadAgg> byLead
  ) {
    if (emailMsgs == null || emailMsgs.isEmpty()) {
      return;
    }
    for (EmailMessage em : emailMsgs) {
      if (em.RelatedToId == null || em.MessageDate == null) {
        continue;
      }
      Id leadCanon = canonicalLeadId(em.RelatedToId, leadMap.keySet(), contactIdToLeadId);
      if (leadCanon == null) {
        continue;
      }
      Lead wfLd = leadMap.get(leadCanon);
      if (!eventStartInLeadWindow(em.MessageDate, wfLd, leadMap)) {
        continue;
      }
      addEmailToLead(byLead, leadCanon);
    }
  }

  @TestVisible
  private static Integer applyEmailMessagesToLeadAggCountForTest(
    List<EmailMessage> emailMsgs,
    Map<Id, Lead> leadMap,
    Map<Id, Id> contactIdToLeadId
  ) {
    Map<Id, OwnerLeadAgg> byLead = new Map<Id, OwnerLeadAgg>();
    applyEmailMessagesToLeadAgg(emailMsgs, leadMap, contactIdToLeadId, byLead);
    Integer n = 0;
    for (OwnerLeadAgg v : byLead.values()) {
      n += v.totalEmails;
    }
    return n;
  }

  /** Nombres de User o Group (cola) para Lead.OwnerId. */
  private static Map<Id, String> resolveOwnerDisplayNames(Set<Id> ownerKeys) {
    Map<Id, String> out = new Map<Id, String>();
    if (ownerKeys == null || ownerKeys.isEmpty()) {
      return out;
    }
    for (User u : [SELECT Id, Name FROM User WHERE Id IN :ownerKeys]) {
      out.put(u.Id, u.Name);
    }
    Set<Id> missing = new Set<Id>(ownerKeys);
    missing.removeAll(out.keySet());
    if (!missing.isEmpty()) {
      for (Group g : [SELECT Id, Name FROM Group WHERE Id IN :missing]) {
        out.put(g.Id, g.Name);
      }
    }
    return out;
  }

  private static Date taskEffectiveActivityDate(Task t) {
    if (t.ActivityDate != null) {
      return t.ActivityDate;
    }
    if (t.CompletedDateTime != null) {
      return t.CompletedDateTime.dateGMT();
    }
    return null;
  }

  private static Boolean activityDateInLeadWindow(
    Date actDate,
    Lead ld,
    Map<Id, Lead> leadMap
  ) {
    Lead fresh = leadMap != null && leadMap.containsKey(ld.Id) ? leadMap.get(ld.Id) : ld;
    Date endD = effectiveReferenceDate(fresh);
    if (endD == null) {
      return false;
    }
    if (actDate > endD) {
      return false;
    }
    Date startD = fresh.CreatedDate.dateGMT();
    return actDate >= startD;
  }

  private static Boolean eventStartInLeadWindow(
    Datetime startDt,
    Lead ld,
    Map<Id, Lead> leadMap
  ) {
    Lead fresh = leadMap != null && leadMap.containsKey(ld.Id) ? leadMap.get(ld.Id) : ld;
    Date sd = startDt.dateGMT();
    Date endD = effectiveReferenceDate(fresh);
    if (endD == null) {
      return false;
    }
    if (sd > endD) {
      return false;
    }
    Date startD = fresh.CreatedDate.dateGMT();
    return sd >= startD;
  }

  @TestVisible
  private static Date effectiveReferenceDateForTest(Lead ld) {
    return effectiveReferenceDate(ld);
  }

  /**
   * Fecha tope del lead: ConvertedDate si IsConverted (Date o DateTime según org); No Cualificado → MKT.
   */
  private static Date effectiveReferenceDate(Lead ld) {
    if (ld.IsConverted == true) {
      Date conv = convertedFieldToDate(ld);
      if (conv != null) {
        return conv;
      }
    }
    if (
      ld.Status != null &&
      ld.Status.equals(LEAD_STATUS_NO_CUALIFICADO) &&
      ld.get(LEAD_CONVERSION_FIELD) != null
    ) {
      return objectToDate(ld.get(LEAD_CONVERSION_FIELD));
    }
    return null;
  }

  /** Lead.ConvertedDate puede ser Date o DateTime según versión/org. */
  private static Date convertedFieldToDate(Lead ld) {
    return objectToDate(ld.get('ConvertedDate'));
  }

  private static Date objectToDate(Object v) {
    if (v instanceof Date) {
      return (Date) v;
    }
    if (v instanceof Datetime) {
      return ((Datetime) v).dateGMT();
    }
    return null;
  }

  private static void assertCanRead() {
    if (!Event.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Eventos.');
    }
    if (!Task.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Tareas.');
    }
    if (!EmailMessage.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer EmailMessage (correos).');
    }
    if (!Lead.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Leads.');
    }
    if (!Contact.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Contactos.');
    }
    if (!Contact.Candidato__c.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Contact.Candidato__c.');
    }
    Map<String, Schema.SObjectField> lm = Lead.SObjectType.getDescribe().fields.getMap();
    if (!lm.containsKey(LEAD_CONVERSION_FIELD)) {
      throw new AuraHandledException('Falta el campo Lead.' + LEAD_CONVERSION_FIELD + ' en la org.');
    }
    if (!lm.get(LEAD_CONVERSION_FIELD).getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Lead.' + LEAD_CONVERSION_FIELD + '.');
    }
    if (!Lead.ConvertedDate.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Lead.ConvertedDate.');
    }
    if (!Lead.IsConverted.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Lead.IsConverted.');
    }
    if (!Lead.Status.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Lead.Status.');
    }
    if (!Lead.OwnerId.getDescribe().isAccessible()) {
      throw new AuraHandledException('No tenés permiso para leer Lead.OwnerId.');
    }
  }

  private static Integer nz(Integer v) {
    return v != null ? v : 0;
  }

  private static String dateToIso(Date d) {
    return d == null ? '' : String.valueOf(d);
  }

  private static List<RelatedContactDto> buildRelatedContactsForLead(
    Id leadId,
    Map<Id, List<Contact>> leadIdToContacts
  ) {
    List<RelatedContactDto> out = new List<RelatedContactDto>();
    if (leadId == null || !leadIdToContacts.containsKey(leadId)) {
      return out;
    }
    List<Contact> clist = new List<Contact>(leadIdToContacts.get(leadId));
    clist.sort(new ContactNameComparator());
    for (Contact cx : clist) {
      RelatedContactDto d = new RelatedContactDto();
      d.contactId = String.valueOf(cx.Id);
      d.contactName = cx.Name != null ? cx.Name : '';
      d.contactUrl = '/' + cx.Id;
      out.add(d);
    }
    return out;
  }

  private class ContactNameComparator implements Comparator<Contact> {
    public Integer compare(Contact a, Contact b) {
      String na = a.Name != null ? a.Name.toLowerCase() : '';
      String nb = b.Name != null ? b.Name.toLowerCase() : '';
      Integer c = na.compareTo(nb);
      if (c != 0) {
        return c;
      }
      return String.valueOf(a.Id).compareTo(String.valueOf(b.Id));
    }
  }

  private class LeadIdByLeadOwnerComparator implements Comparator<Id> {
    Map<Id, Lead> leadMap;
    Map<Id, String> ownerNames;
    LeadIdByLeadOwnerComparator(Map<Id, Lead> leadMap, Map<Id, String> ownerNames) {
      this.leadMap = leadMap;
      this.ownerNames = ownerNames;
    }
    public Integer compare(Id aId, Id bId) {
      Lead la = leadMap.get(aId);
      Lead lb = leadMap.get(bId);
      String oa = ownerLabel(la != null ? la.OwnerId : null);
      String ob = ownerLabel(lb != null ? lb.OwnerId : null);
      Integer c = oa.compareTo(ob);
      if (c != 0) {
        return c;
      }
      String na = la != null && la.Name != null ? la.Name.toLowerCase() : '';
      String nb = lb != null && lb.Name != null ? lb.Name.toLowerCase() : '';
      c = na.compareTo(nb);
      if (c != 0) {
        return c;
      }
      return String.valueOf(aId).compareTo(String.valueOf(bId));
    }
    private String ownerLabel(Id oid) {
      if (oid == null) {
        return '';
      }
      String n = ownerNames.get(oid);
      return n != null ? n.toLowerCase() : '';
    }
  }

}