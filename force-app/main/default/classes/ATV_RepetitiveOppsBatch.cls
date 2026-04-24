public with sharing class ATV_RepetitiveOppsBatch implements Database.Batchable<SObject>, Database.Stateful {
	private Date runDate;

	// Summary counters
	Integer totalScopes                = 0;
	Integer totalAP_Scanned            = 0;
	Integer totalAP_Due                = 0;
	Integer totalAccountsDue           = 0;
	Integer totalOppsInserted          = 0;
	Integer totalOLIsInserted          = 0;
	Integer totalAPsUpdated            = 0;
	Integer totalOCRsInserted          = 0;
	Integer totalOppsAOCUpdated        = 0;
	Integer totalOppsStageUpdated      = 0;
	Set<Id>  accountsSeen              = new Set<Id>();
	Set<Id>  accountsWithPBE           = new Set<Id>();
	List<String> errorLines            = new List<String>();
	List<String> notCreatedLines       = new List<String>();
	@TestVisible static Boolean TEST_FORCE_OPP_INSERT_CATCH      = false;
	@TestVisible static Boolean TEST_FORCE_OCR_INSERT_CATCH      = false;
	@TestVisible static Boolean TEST_FORCE_AOC_UPDATE_CATCH      = false;
	@TestVisible static Boolean TEST_FORCE_OLI_INSERT_CATCH      = false;
	@TestVisible static Boolean TEST_FORCE_AP_UPDATE_CATCH       = false;
	@TestVisible static Boolean TEST_FORCE_STAGE_UPDATE_CATCH    = false;
	@TestVisible static Boolean TEST_FORCE_RENAME_UPDATE_CATCH   = false;
	@TestVisible static Boolean TEST_FORCE_RUNTIME_PB           = false;

	public ATV_RepetitiveOppsBatch() {
		this.runDate = Date.today();
	}
	public ATV_RepetitiveOppsBatch(Date runDate) {
		this.runDate = runDate;
	}

	@TestVisible static Id resolveStandardPricebookId() {
		if (Test.isRunningTest()) {
			if (TEST_FORCE_RUNTIME_PB) {
				Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
				return std.Id;
			}
			return Test.getStandardPricebookId();
		} else {
			Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
			return std.Id;
		}
	}

	// Test helpers (no side effects on main flow)
	@TestVisible static Map<Id, List<AccountProduct__c>> buildItemsByAccount(
		List<AccountProduct__c> due,
		Map<Id, PricebookEntry> pbeByProduct,
		Set<Id> accountsWithPBEOut
	) {
		Map<Id, List<AccountProduct__c>> itemsByAccountOut = new Map<Id, List<AccountProduct__c>>();
		if (due == null || due.isEmpty()) return itemsByAccountOut;
		for (AccountProduct__c ap : due) {
			if (ap == null) continue;
			PricebookEntry pbe = (ap.Producto__c == null ? null : pbeByProduct.get(ap.Producto__c));
			if (pbe == null) continue;
			if (!itemsByAccountOut.containsKey(ap.Cliente__c)) itemsByAccountOut.put(ap.Cliente__c, new List<AccountProduct__c>());
			itemsByAccountOut.get(ap.Cliente__c).add(ap);
			if (accountsWithPBEOut != null && ap.Cliente__c != null) accountsWithPBEOut.add(ap.Cliente__c);
		}
		return itemsByAccountOut;
	}

	@TestVisible static Map<Id, Id> mapOwnersByAccount(List<Account> accounts) {
		Map<Id, Id> ownerMap = new Map<Id, Id>();
		if (accounts == null) return ownerMap;
		for (Account a : accounts) {
			if (a != null) ownerMap.put(a.Id, a.OwnerId);
		}
		return ownerMap;
	}

	@TestVisible static void renameOpps(List<Opportunity> oppsToInsert, Map<Id, String> nameByAccount, String oppNamePrefix) {
		if (oppsToInsert == null || oppsToInsert.isEmpty()) return;
		for (Opportunity o : oppsToInsert) {
			if (o == null) continue;
			String accName = (nameByAccount == null ? null : nameByAccount.get(o.AccountId));
			Opportunity current = [SELECT Id, Opportunity_Number__c FROM Opportunity WHERE Id = :o.Id LIMIT 1];
			String newName = oppNamePrefix + (accName == null ? 'Cuenta' : accName) + ' - ' + String.valueOf(current.Opportunity_Number__c);
			o.Name = newName;
		}
	}

	/**
	 * Calcula el último día del mes basado en la fecha proporcionada.
	 * Maneja correctamente meses con diferentes cantidades de días (28, 29, 30, 31).
	 * @param inputDate Fecha de referencia
	 * @return Último día del mes de la fecha proporcionada
	 */
	@TestVisible static Date getLastDayOfMonth(Date inputDate) {
		if (inputDate == null) return null;
		Integer year = inputDate.year();
		Integer month = inputDate.month();
		Integer daysInMonth = Date.daysInMonth(year, month);
		return Date.newInstance(year, month, daysInMonth);
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		String soql = 'SELECT Id, Cliente__c, Producto__c, CantidadTipica__c, Precio__c, Ultima_Compra__c, FrecuenciaCompra__c, NextPurchaseDate__c ' +
			'FROM AccountProduct__c WHERE NextPurchaseDate__c != NULL AND NextPurchaseDate__c <= :runDate';
		return Database.getQueryLocator(soql);
	}

	public void execute(Database.BatchableContext bc, List<SObject> scope) {
		totalScopes++;
		List<AccountProduct__c> typedScope = new List<AccountProduct__c>();
		for (SObject s : scope) typedScope.add((AccountProduct__c) s);
		totalAP_Scanned += typedScope.size();

		List<AccountProduct__c> due = typedScope; // ya filtrados por NextPurchaseDate__c
		totalAP_Due += due.size();
		if (due.isEmpty()) return;

		Set<Id> accountIds = new Set<Id>();
		Set<Id> productIds = new Set<Id>();
		for (AccountProduct__c ap : due) {
			if (ap.Cliente__c != null) { accountIds.add(ap.Cliente__c); accountsSeen.add(ap.Cliente__c); }
			if (ap.Producto__c != null) productIds.add(ap.Producto__c);
		}
		totalAccountsDue += accountIds.size();
		if (accountIds.isEmpty() || productIds.isEmpty()) return;

		Id stdId = resolveStandardPricebookId();
		Map<Id, PricebookEntry> pbeByProduct = new Map<Id, PricebookEntry>();
		for (PricebookEntry pbe : [
			SELECT Id, Product2Id, UnitPrice
			FROM PricebookEntry
			WHERE Pricebook2Id = :stdId AND IsActive = true AND Product2Id IN :productIds
		]) {
			if (!pbeByProduct.containsKey(pbe.Product2Id)) pbeByProduct.put(pbe.Product2Id, pbe);
		}

		Map<Id, ATV_AOC_DTO> aocByAccount = ATV_AOC_BulkService.getByAccounts(accountIds);

		Map<Id, List<AccountProduct__c>> itemsByAccount = new Map<Id, List<AccountProduct__c>>();
		for (AccountProduct__c ap : due) {
			PricebookEntry pbe = pbeByProduct.get(ap.Producto__c);
			if (pbe == null) continue;
			if (!itemsByAccount.containsKey(ap.Cliente__c)) itemsByAccount.put(ap.Cliente__c, new List<AccountProduct__c>());
			itemsByAccount.get(ap.Cliente__c).add(ap);
			accountsWithPBE.add(ap.Cliente__c);
		}
		if (itemsByAccount.isEmpty()) return;

		String oppNamePrefix = 'Repetitiva - ';
		List<Opportunity> oppsToInsert = new List<Opportunity>();
		Map<Id, Id> ownerByAccount = new Map<Id, Id>();
		Map<Id, String> nameByAccount = new Map<Id, String>();
		for (Account a : [SELECT Id, OwnerId, Name FROM Account WHERE Id IN :accountIds]) {
			ownerByAccount.put(a.Id, a.OwnerId);
			nameByAccount.put(a.Id, a.Name);
		}

		// Calcular fecha de cierre: último día del mes de runDate
		Date closeDate = getLastDayOfMonth(runDate);

		// Mapear oportunidades existentes por cuenta (reutilizar si ya hay una repetitiva para el período)
		Map<Id, Opportunity> oppByAccount = new Map<Id, Opportunity>();
		try {
			for (Opportunity ex : [
				SELECT Id, AccountId
				FROM Opportunity
				WHERE Repetitiva__c = true AND AccountId IN :accountIds AND CloseDate = :closeDate
				ORDER BY CreatedDate DESC
			]) {
				if (!oppByAccount.containsKey(ex.AccountId)) {
					oppByAccount.put(ex.AccountId, ex);
				}
			}
		} catch (Exception e) {
			errorLines.add('Query existing Opps error: ' + e.getMessage());
		}

		// Crear oportunidades solo para las cuentas que no tienen una existente para el período
		for (Id accId : itemsByAccount.keySet()) {
			if (oppByAccount.containsKey(accId)) continue;
			Opportunity o = new Opportunity();
			o.AccountId    = accId;
			o.Name         = oppNamePrefix + (nameByAccount.containsKey(accId) ? nameByAccount.get(accId) : 'Cuenta') + ' - pending';
			o.CloseDate    = closeDate;
			o.StageName    = 'MQL';
			o.Type         = 'Existing Business CE (R)';
			o.Pricebook2Id = stdId;
			o.Repetitiva__c= true;
			o.OwnerId      = ownerByAccount.get(accId);
			oppsToInsert.add(o);
		}
		if (!oppsToInsert.isEmpty()) {
			try {
				if (Test.isRunningTest() && TEST_FORCE_OPP_INSERT_CATCH) { insert new Opportunity(); }
				insert oppsToInsert;
				totalOppsInserted += oppsToInsert.size();
				for (Opportunity o : oppsToInsert) oppByAccount.put(o.AccountId, o);
			} catch (Exception e) {
				errorLines.add('Insert Opps error: ' + e.getMessage());
				return;
			}
		}

		List<OpportunityContactRole> ocrToInsert = new List<OpportunityContactRole>();
		List<Opportunity> oppsToUpdateAOC = new List<Opportunity>();
		for (Id accId : oppByAccount.keySet()) {
			ATV_AOC_DTO cfg = aocByAccount.get(accId);
			Opportunity o = oppByAccount.get(accId);
			Boolean touched = false;
			if (cfg != null) {
				if (cfg.contactoPrincipalId != null) {
					ocrToInsert.add(new OpportunityContactRole(
						OpportunityId = o.Id,
						ContactId     = cfg.contactoPrincipalId,
						IsPrimary     = true
					));
				}
				if (String.isNotBlank(cfg.competencia)) { 
					o.Competencia__c = cfg.competencia; 
					touched = true; 
					// Si competencia es "Otro", completar Otro_Competidor__c
					if (cfg.competencia == 'Otro') {
						o.Otro_Competidor__c = 'Otro';
					}
				}
				if (String.isNotBlank(cfg.puntoDeDolor)) { o.Pain_Points__c = cfg.puntoDeDolor; touched = true; }
			}
			if (touched) oppsToUpdateAOC.add(o);
		}
		if (!ocrToInsert.isEmpty()) {
			try { if (Test.isRunningTest() && TEST_FORCE_OCR_INSERT_CATCH) { insert new OpportunityContactRole(); } insert ocrToInsert; totalOCRsInserted += ocrToInsert.size(); }
			catch (Exception e) { errorLines.add('Insert OCR error: ' + e.getMessage()); }
		}
		if (!oppsToUpdateAOC.isEmpty()) {
			try { if (Test.isRunningTest() && TEST_FORCE_AOC_UPDATE_CATCH) { update new Opportunity(); } update oppsToUpdateAOC; totalOppsAOCUpdated += oppsToUpdateAOC.size(); }
			catch (Exception e) { errorLines.add('Update Opp(AOC) error: ' + e.getMessage()); }
		}

		List<OpportunityLineItem> olisToInsert = new List<OpportunityLineItem>();
		for (Id accId : itemsByAccount.keySet()) {
			Opportunity o = oppByAccount.get(accId);
			if (o == null) continue;
			for (AccountProduct__c ap : itemsByAccount.get(accId)) {
				PricebookEntry pbe = pbeByProduct.get(ap.Producto__c);
				if (pbe == null) continue;
				// Siempre agregar líneas a la oportunidad objetivo (nueva o existente)
				olisToInsert.add(new OpportunityLineItem(
					OpportunityId    = o.Id,
					PricebookEntryId = pbe.Id,
					Quantity         = (ap.CantidadTipica__c == null ? 1 : (Decimal) ap.CantidadTipica__c),
					UnitPrice        = (ap.Precio__c == null ? pbe.UnitPrice : (Decimal) ap.Precio__c)
				));
			}
		}
		if (!olisToInsert.isEmpty()) {
			try { if (Test.isRunningTest() && TEST_FORCE_OLI_INSERT_CATCH) { insert new OpportunityLineItem(); } insert olisToInsert; totalOLIsInserted += olisToInsert.size(); }
			catch (Exception e) { errorLines.add('Insert OLI error: ' + e.getMessage()); }
		}

		for (AccountProduct__c ap : due) ap.Ultima_Compra__c = ap.NextPurchaseDate__c;
		try { if (Test.isRunningTest() && TEST_FORCE_AP_UPDATE_CATCH) { update new AccountProduct__c(); } update due; totalAPsUpdated += due.size(); }
		catch (Exception e) { errorLines.add('Update AP error: ' + e.getMessage()); }

		List<Opportunity> oppsStage = new List<Opportunity>();
		for (Id accId : itemsByAccount.keySet()) {
			Opportunity o = oppByAccount.get(accId);
			if (o != null) {
				ATV_AOC_DTO cfg = aocByAccount.get(accId);
				Boolean hasAllAOC = (cfg != null && cfg.contactoPrincipalId != null && String.isNotBlank(cfg.competencia) && String.isNotBlank(cfg.puntoDeDolor));
				if (hasAllAOC) { o.StageName = 'Atención'; oppsStage.add(o); }
			}
		}
		if (!oppsStage.isEmpty()) {
			try { if (Test.isRunningTest() && TEST_FORCE_STAGE_UPDATE_CATCH) { update new Opportunity(); } update oppsStage; totalOppsStageUpdated += oppsStage.size(); }
			catch (Exception e) { errorLines.add('Update Opp(Stage) error: ' + e.getMessage()); }
		}

		List<Opportunity> oppsToRename = new List<Opportunity>();
		for (Opportunity o : oppsToInsert) {
			String accName = nameByAccount.get(o.AccountId);
			Opportunity current = [SELECT Id, Opportunity_Number__c FROM Opportunity WHERE Id = :o.Id LIMIT 1];
			String newName = oppNamePrefix + (accName == null ? 'Cuenta' : accName) + ' - ' + String.valueOf(current.Opportunity_Number__c);
			o.Name = newName;
			oppsToRename.add(o);
		}
		try { if (Test.isRunningTest() && TEST_FORCE_RENAME_UPDATE_CATCH) { update new Opportunity(); } update oppsToRename; } catch (Exception e) { errorLines.add('Update Opp(Name) error: ' + e.getMessage()); }

		Set<Id> hadItems = new Set<Id>(itemsByAccount.keySet());
		for (Id accId : accountIds) {
			if (!hadItems.contains(accId)) {
				String accName = nameByAccount.get(accId);
				notCreatedLines.add((accName == null ? String.valueOf(accId) : accName) + ': sin PricebookEntry activo para productos vencidos');
			}
		}
	}

	public void finish(Database.BatchableContext bc) {
		List<String> to = new List<String>();
		// Fijamos destinatario por requerimiento
		to.add('salesforce@atvault.com');
		String subject = 'Resumen oportunidades repetitivas - ' + runDate.format();
		String html =
			'<h2>Resumen ejecución Oportunidades Repetitivas</h2>' +
			'<p><b>Fecha corrida:</b> ' + runDate.format() + '</p>' +
			'<table border="1" cellpadding="6" cellspacing="0">' +
			row('Scopes procesados', String.valueOf(totalScopes)) +
			row('AccountProduct revisados', String.valueOf(totalAP_Scanned)) +
			row('AccountProduct "vencen hoy"', String.valueOf(totalAP_Due)) +
			row('Cuentas con vencimiento en el lote', String.valueOf(totalAccountsDue)) +
			row('Cuentas con PBE válido', String.valueOf(accountsWithPBE.size())) +
			row('Oportunidades creadas', String.valueOf(totalOppsInserted)) +
			row('OpportunityLineItems creados', String.valueOf(totalOLIsInserted)) +
			row('AccountProduct actualizados', String.valueOf(totalAPsUpdated)) +
			row('Contact Roles creados', String.valueOf(totalOCRsInserted)) +
			row('Opps actualizadas con AOC', String.valueOf(totalOppsAOCUpdated)) +
			row('Opps pasadas a "Atención"', String.valueOf(totalOppsStageUpdated)) +
			'</table>' +
			(notCreatedLines.isEmpty() ? '' : '<h3>No se crearon oportunidades</h3><ul><li>' + String.join(notCreatedLines, '</li><li>') + '</li></ul>') +
			(errorLines.isEmpty() ? '' : '<h3>Errores</h3><ul><li>' + String.join(errorLines, '</li><li>') + '</li></ul>');

		try {
			Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
			msg.setToAddresses(to);
			msg.setSubject(subject);
			msg.setHtmlBody(html);
			Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ msg });
		} catch (Exception e) {
			System.debug('No se pudo enviar el email de resumen: ' + e.getMessage());
		}
	}

	private static String row(String label, String val) {
		return '<tr><td><b>' + label.escapeHtml4() + '</b></td><td>' + val.escapeHtml4() + '</td></tr>';
	}
}