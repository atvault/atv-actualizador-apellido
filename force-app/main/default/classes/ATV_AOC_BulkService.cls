public with sharing class ATV_AOC_BulkService {
	public class Request {
		@InvocableVariable(required=true)
		public List<Id> accountIds;
	}

	// Service reutilizable (scheduler puede llamarlo directo)
	public static Map<Id, ATV_AOC_DTO> getByAccounts(Set<Id> accIds) {
		Map<Id, ATV_AOC_DTO> out = new Map<Id, ATV_AOC_DTO>();
		if (accIds == null || accIds.isEmpty()) return out;

		for (AccountOpportunityConfig__c a : [
			SELECT Id, Account__c, ContactoPrincipal__c, Competencia__c, PuntoDeDolor__c
			FROM AccountOpportunityConfig__c
			WHERE Account__c IN :accIds
		]) {
			ATV_AOC_DTO dto = new ATV_AOC_DTO();
			dto.accountId = a.Account__c;
			dto.aocId = a.Id;
			dto.contactoPrincipalId = a.ContactoPrincipal__c;
			dto.competencia = a.Competencia__c;
			dto.puntoDeDolor = a.PuntoDeDolor__c;
			out.put(dto.accountId, dto);
		}
		// completar “vacíos” para cuentas sin config
		for (Id aid : accIds) if (!out.containsKey(aid)) {
			ATV_AOC_DTO e = new ATV_AOC_DTO(); e.accountId = aid; out.put(aid, e);
		}
		return out;
	}

	@InvocableMethod(label='Fetch AOC by Accounts')
	public static List<ATV_AOC_DTO> fetch(List<Request> reqs) {
		Set<Id> ids = new Set<Id>();
		for (Request r : reqs) if (r != null && r.accountIds != null) ids.addAll(r.accountIds);
		return new List<ATV_AOC_DTO>( getByAccounts(ids).values() );
	}
}