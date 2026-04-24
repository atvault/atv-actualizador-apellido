/**
 * Lógica de consulta del reporte de eventos (sin Aura). Invocar desde el controlador LWC.
 */
public with sharing class CastleEventsReportSvc {
  private static final Integer MAX_SOQL_OFFSET = 2000;
  private static final Integer DEFAULT_PAGE_SIZE = 25;

  public class EventFilterDto {
    public Datetime startDateTimeFrom { get; set; }
    public Datetime startDateTimeTo { get; set; }
    public Id ownerUserId { get; set; }
    public String subjectContains { get; set; }
    public String locationContains { get; set; }
    public String timeScope { get; set; }
  }

  public class KeysetCursorDto {
    public String lastStartDateTimeIso { get; set; }
    public String lastEventId { get; set; }
  }

  public class EventRowDto {
    public String eventId { get; set; }
    public String eventUrl { get; set; }
    public String subject { get; set; }
    public Datetime startDateTime { get; set; }
    public Datetime endDateTime { get; set; }
    public String location { get; set; }
    public Datetime createdDate { get; set; }
    public String ownerId { get; set; }
    public String ownerName { get; set; }
    public String ownerUrl { get; set; }
    public String whoId { get; set; }
    public String contactName { get; set; }
    public String contactUrl { get; set; }
    public String candidatoId { get; set; }
    public String candidatoName { get; set; }
    public String candidatoUrl { get; set; }
    public Boolean candidatoIsConverted { get; set; }
    public String whatId { get; set; }
  }

  public class EventQueryResultDto {
    public Integer totalRows { get; set; }
    /** Cantidad de Leads (Candidato) distintos entre los contactos de los eventos filtrados */
    public Integer distinctCandidateCount { get; set; }
    /** totalRows / distinctCandidateCount (mismos filtros que el listado) */
    public Decimal averageEventsPerCandidate { get; set; }
    public List<EventRowDto> rows { get; set; }
    public KeysetCursorDto nextCursor { get; set; }
    public Boolean usedKeyset { get; set; }
  }

  private class FilterVars {
    Datetime startFrom;
    Datetime startTo;
    Id ownerId;
    String subjectLike;
    String locationLike;
    Datetime nowDt;
    String timeScope;
  }

  public static EventQueryResultDto getEvents(
    EventFilterDto filters,
    Integer pageSize,
    Integer pageNumber,
    String sortBy,
    String sortDir,
    KeysetCursorDto keysetCursor
  ) {
    Integer ps = pageSize == null || pageSize < 1 ? DEFAULT_PAGE_SIZE : Math.min(pageSize, 200);
    Integer pn = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
    String sb = String.isBlank(sortBy) ? 'StartDateTime' : sortBy;
    String sd = String.isBlank(sortDir) ? 'desc' : sortDir.toLowerCase();

    FilterVars fv = prepareFilterVars(filters);
    Datetime startFrom = fv.startFrom;
    Datetime startTo = fv.startTo;
    Id ownerId = fv.ownerId;
    String subjectLike = fv.subjectLike;
    String locationLike = fv.locationLike;
    Datetime nowDt = fv.nowDt;

    String extraWhere = buildExtraWhereSql(fv);

    EventQueryResultDto out = new EventQueryResultDto();
    out.rows = new List<EventRowDto>();
    out.totalRows = countMatching(extraWhere, startFrom, startTo, ownerId, subjectLike, locationLike, nowDt);
    out.distinctCandidateCount = 0;
    out.averageEventsPerCandidate = null;
    out.usedKeyset = false;

    if (out.totalRows == 0) {
      out.nextCursor = null;
      return out;
    }

    Integer dc = countDistinctCandidates(extraWhere, startFrom, startTo, ownerId, subjectLike, locationLike, nowDt);
    out.distinctCandidateCount = dc;
    if (dc != null && dc > 0) {
      out.averageEventsPerCandidate = Decimal.valueOf(out.totalRows).divide(Decimal.valueOf(dc), 2);
    }

    String orderClause = buildOrderClause(sb, sd);
    Boolean defaultKeysetSort = sb.equalsIgnoreCase('StartDateTime') && sd == 'desc';

    Integer offsetRows = (pn - 1) * ps;
    Boolean useKeyset =
      defaultKeysetSort &&
      keysetCursor != null &&
      !String.isBlank(keysetCursor.lastEventId) &&
      !String.isBlank(keysetCursor.lastStartDateTimeIso);

    if (!useKeyset && offsetRows > MAX_SOQL_OFFSET) {
      if (defaultKeysetSort) {
        throw new AuraHandledException(
          'Hay más resultados de los que se pueden saltar con OFFSET. Usá "Siguiente página" con cursor o refiná los filtros. (Límite SOQL OFFSET ' +
          MAX_SOQL_OFFSET +
          ')'
        );
      }
      throw new AuraHandledException(
        'Demasiados registros para esta página. Refiná filtros u ordená por Fecha de inicio (desc) para paginación extendida.'
      );
    }

    Datetime ksTime;
    Id ksId;
    if (useKeyset) {
      ksTime = parseIsoToDatetimeGmt(keysetCursor.lastStartDateTimeIso);
      ksId = keysetCursor.lastEventId;
    }

    String selectFields =
      'Id, Subject, StartDateTime, EndDateTime, Location, CreatedDate, OwnerId, WhoId, WhatId, ' +
      'Owner.Name, ' +
      'TYPEOF Who WHEN Contact THEN Id, Name, Candidato__c, Candidato__r.Name, Candidato__r.IsConverted END';

    String keysetSql = '';
    if (useKeyset) {
      keysetSql = ' AND (StartDateTime < :ksTime OR (StartDateTime = :ksTime AND Id < :ksId)) ';
    }

    String query =
      'SELECT ' +
      selectFields +
      ' FROM Event WHERE WhoId IN (SELECT Id FROM Contact WHERE Candidato__c != null AND Candidato__r.IsConverted = true) ' +
      extraWhere +
      keysetSql +
      ' ' +
      orderClause +
      ' LIMIT ' +
      String.valueOf(ps);

    if (!useKeyset) {
      query += ' OFFSET ' + String.valueOf(offsetRows);
    }

    List<Event> raw;
    try {
      raw = Database.query(query);
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'No se pudo ejecutar la consulta. Verificá FLS y que Candidato__r.IsConverted exista en el destino del lookup: ' +
        qe.getMessage()
      );
    }

    for (Event ev : raw) {
      out.rows.add(mapRow(ev));
    }

    if (defaultKeysetSort && !out.rows.isEmpty()) {
      EventRowDto last = out.rows[out.rows.size() - 1];
      Integer shown = (pn - 1) * ps + out.rows.size();
      if (out.totalRows > shown) {
        KeysetCursorDto nc = new KeysetCursorDto();
        nc.lastEventId = last.eventId;
        nc.lastStartDateTimeIso = formatIsoGmt(last.startDateTime);
        out.nextCursor = nc;
      }
    }

    out.usedKeyset = useKeyset;
    return out;
  }

  private static FilterVars prepareFilterVars(EventFilterDto filters) {
    FilterVars v = new FilterVars();
    v.nowDt = System.now();
    if (filters == null) {
      return v;
    }
    v.startFrom = filters.startDateTimeFrom;
    v.startTo = filters.startDateTimeTo;
    v.ownerId = filters.ownerUserId;
    if (!String.isBlank(filters.subjectContains)) {
      v.subjectLike = '%' + filters.subjectContains + '%';
    }
    if (!String.isBlank(filters.locationContains)) {
      v.locationLike = '%' + filters.locationContains + '%';
    }
    v.timeScope = filters.timeScope;
    return v;
  }

  private static String buildExtraWhereSql(FilterVars v) {
    String s = '';
    if (v.subjectLike != null) {
      s += ' AND Subject LIKE :subjectLike ';
    }
    if (v.locationLike != null) {
      s += ' AND Location LIKE :locationLike ';
    }
    if (v.startFrom != null) {
      s += ' AND StartDateTime >= :startFrom ';
    }
    if (v.startTo != null) {
      s += ' AND StartDateTime <= :startTo ';
    }
    if (v.ownerId != null) {
      s += ' AND OwnerId = :ownerId ';
    }
    if (v.timeScope == 'future') {
      s += ' AND StartDateTime >= :nowDt ';
    } else if (v.timeScope == 'past') {
      s += ' AND StartDateTime < :nowDt ';
    }
    return s;
  }

  private static Integer countMatching(
    String extraWhere,
    Datetime startFrom,
    Datetime startTo,
    Id ownerId,
    String subjectLike,
    String locationLike,
    Datetime nowDt
  ) {
    String q =
      'SELECT COUNT() FROM Event WHERE WhoId IN (SELECT Id FROM Contact WHERE Candidato__c != null AND Candidato__r.IsConverted = true) ' +
      extraWhere;
    return (Integer) Database.countQuery(q);
  }

  /**
   * Candidatos (Lead) distintos vía Contact.Candidato__c.
   * No se puede usar Contact Id IN (SELECT WhoId FROM Event...) en SOQL; se leen WhoId de Event y luego Contact por lotes.
   */
  private static Integer countDistinctCandidates(
    String extraWhere,
    Datetime startFrom,
    Datetime startTo,
    Id ownerId,
    String subjectLike,
    String locationLike,
    Datetime nowDt
  ) {
    String q =
      'SELECT WhoId FROM Event WHERE WhoId IN (SELECT Id FROM Contact WHERE Candidato__c != null AND Candidato__r.IsConverted = true) ' +
      extraWhere;
    Set<Id> whoIds = new Set<Id>();
    for (Event ev : (List<Event>) Database.query(q)) {
      if (ev.WhoId != null) {
        whoIds.add(ev.WhoId);
      }
    }
    if (whoIds.isEmpty()) {
      return 0;
    }
    Set<Id> leadIds = new Set<Id>();
    List<Id> idList = new List<Id>(whoIds);
    final Integer chunk = 2000;
    for (Integer i = 0; i < idList.size(); i += chunk) {
      Integer endIdx = Math.min(i + chunk, idList.size());
      List<Id> subset = new List<Id>();
      for (Integer j = i; j < endIdx; j++) {
        subset.add(idList[j]);
      }
      for (Contact c : [
        SELECT Candidato__c
        FROM Contact
        WHERE Id IN :subset AND Candidato__c != null
      ]) {
        leadIds.add(c.Candidato__c);
      }
    }
    return leadIds.size();
  }

  private static EventRowDto mapRow(Event ev) {
    EventRowDto row = new EventRowDto();
    row.eventId = ev.Id;
    row.eventUrl = '/' + ev.Id;
    row.subject = ev.Subject;
    row.startDateTime = ev.StartDateTime;
    row.endDateTime = ev.EndDateTime;
    row.location = ev.Location;
    row.createdDate = ev.CreatedDate;
    row.ownerId = ev.OwnerId;
    if (ev.Owner != null) {
      row.ownerName = ev.Owner.Name;
      row.ownerUrl = '/' + ev.OwnerId;
    }
    row.whoId = ev.WhoId;
    row.whatId = ev.WhatId;

    Contact c = (Contact) ev.getSObject('Who');
    if (c != null) {
      row.contactName = c.Name;
      row.contactUrl = '/' + c.Id;
      row.candidatoId = (String) c.get('Candidato__c');
      SObject cand = c.getSObject('Candidato__r');
      if (cand != null) {
        row.candidatoName = (String) cand.get('Name');
        row.candidatoIsConverted = (Boolean) cand.get('IsConverted');
        row.candidatoUrl = '/' + cand.Id;
      }
    }
    return row;
  }

  @TestVisible
  private static String buildOrderClause(String sortBy, String sortDir) {
    String dir = sortDir == 'asc' ? 'ASC' : 'DESC';
    String f;
    switch on sortBy.toLowerCase() {
      when 'subject' {
        f = 'Subject';
      }
      when 'startdatetime' {
        f = 'StartDateTime';
      }
      when 'enddatetime' {
        f = 'EndDateTime';
      }
      when 'location' {
        f = 'Location';
      }
      when 'createddate' {
        f = 'CreatedDate';
      }
      when 'ownername' {
        f = 'Owner.Name';
      }
      when else {
        f = 'StartDateTime';
      }
    }
    if (f == 'StartDateTime') {
      return 'ORDER BY StartDateTime ' + dir + ', Id ' + dir;
    }
    return 'ORDER BY ' + f + ' ' + dir + ', Id ' + dir;
  }

  @TestVisible
  private static Datetime parseIsoToDatetimeGmt(String iso) {
    if (String.isBlank(iso)) {
      return null;
    }
    String s = iso.replace('T', ' ').replace('Z', '');
    if (s.contains('.')) {
      s = s.substringBefore('.');
    }
    return Datetime.valueOfGmt(s);
  }

  @TestVisible
  private static String formatIsoGmt(Datetime dt) {
    if (dt == null) {
      return null;
    }
    return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
  }
}