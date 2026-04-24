public with sharing class ATV_AOC_DTO {
	@AuraEnabled @InvocableVariable public Id    accountId;
	@AuraEnabled @InvocableVariable public Id    aocId;
	@AuraEnabled @InvocableVariable public Id    contactoPrincipalId;
	@AuraEnabled @InvocableVariable public String competencia;
	@AuraEnabled @InvocableVariable public String puntoDeDolor; // multiselect como texto ';'
}