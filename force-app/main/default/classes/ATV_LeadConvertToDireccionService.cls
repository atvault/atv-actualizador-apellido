public with sharing class ATV_LeadConvertToDireccionService {
    private static final String DEFAULT_PROVINCIA = 'Buenos Aires';

    public static void createFromConvertedLeads(List<Lead> newList, Map<Id, Lead> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Set<String> allowedProvincias = getActiveProvinciaPicklistValues();
        List<ATV_NTS_Direccion_de_Envio__c> toInsert = new List<ATV_NTS_Direccion_de_Envio__c>();
        Map<Id, String> accountEmailById = new Map<Id, String>();

        for (Lead l : newList) {
            Lead oldLead = oldMap != null ? oldMap.get(l.Id) : null;
            Boolean justConverted = l.IsConverted
                && l.ConvertedAccountId != null
                && (oldLead == null || oldLead.IsConverted == false);

            if (!justConverted) {
                continue;
            }

            if (String.isNotBlank(l.CorreoElectronicoCorporativo__c)) {
                accountEmailById.put(l.ConvertedAccountId, l.CorreoElectronicoCorporativo__c);
            }

            if (String.isBlank(l.Street)
                && String.isBlank(l.City)
                && String.isBlank(l.State)
                && String.isBlank(l.PostalCode)
                && String.isBlank(l.Country)) {
                continue;
            }

            ATV_NTS_Direccion_de_Envio__c dir = new ATV_NTS_Direccion_de_Envio__c();
            dir.Account__c = l.ConvertedAccountId;
            dir.Name = buildDireccionName(l);
            dir.NTS_fld_ShippingStreet__c = l.Street;
            dir.NTS_fld_ShippingCity__c = l.City;
            dir.NTS_fld_ShippingCountry__c = l.Country;
            dir.ATV_fld_ShippingPostalCode__c = l.PostalCode;
            dir.Estado_o_Provincia__c = l.State;
            dir.ATV_NTS_Provincia__c = mapStateToProvincia(l.State, allowedProvincias);
            dir.Direccion_predeterminada__c = false;
            dir.Direccion_predeterminada_facturacion__c = true;
            toInsert.add(dir);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        syncAccountEmailOnLeadConversion(accountEmailById);
    }

    private static void syncAccountEmailOnLeadConversion(Map<Id, String> accountEmailById) {
        if (accountEmailById == null || accountEmailById.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = [
            SELECT Id, Email__c
            FROM Account
            WHERE Id IN :accountEmailById.keySet()
        ];

        List<Account> updates = new List<Account>();
        for (Account acc : accountsToUpdate) {
            String leadCorpEmail = accountEmailById.get(acc.Id);
            if (String.isBlank(acc.Email__c) && String.isNotBlank(leadCorpEmail)) {
                acc.Email__c = leadCorpEmail;
                updates.add(acc);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static String buildDireccionName(Lead l) {
        String raw = String.isNotBlank(l.Company)
            ? l.Company
            : (String.isNotBlank(l.LastName) ? l.LastName : 'Direccion Lead');

        Integer maxLen = 80;
        return raw.length() > maxLen ? raw.substring(0, maxLen) : raw;
    }

    @TestVisible
    private static String mapStateToProvincia(String leadState, Set<String> allowedValues) {
        if (allowedValues == null || allowedValues.isEmpty()) {
            return null;
        }

        Map<String, String> allowedByNorm = new Map<String, String>();
        for (String v : allowedValues) {
            if (String.isNotBlank(v)) {
                allowedByNorm.put(normalizeKey(v), v);
            }
        }

        String stateNorm = normalizeKey(leadState);
        if (String.isNotBlank(stateNorm) && allowedByNorm.containsKey(stateNorm)) {
            return allowedByNorm.get(stateNorm);
        }

        Map<String, String> aliases = new Map<String, String>{
            'BS AS' => 'Buenos Aires',
            'BSAS' => 'Buenos Aires',
            'PBA' => 'Buenos Aires',
            'PROVINCIA DE BUENOS AIRES' => 'Buenos Aires',
            'PCIA DE BUENOS AIRES' => 'Buenos Aires',
            'PCIA BUENOS AIRES' => 'Buenos Aires',
            'CABA' => 'Capital Federal',
            'CIUDAD AUTONOMA DE BUENOS AIRES' => 'Capital Federal'
        };

        if (String.isNotBlank(stateNorm) && aliases.containsKey(stateNorm)) {
            String mapped = aliases.get(stateNorm);
            String mappedNorm = normalizeKey(mapped);
            if (allowedByNorm.containsKey(mappedNorm)) {
                return allowedByNorm.get(mappedNorm);
            }
        }

        String defaultNorm = normalizeKey(DEFAULT_PROVINCIA);
        if (allowedByNorm.containsKey(defaultNorm)) {
            return allowedByNorm.get(defaultNorm);
        }

        List<String> values = new List<String>();
        values.addAll(allowedValues);
        values.sort();
        return values[0];
    }

    private static Set<String> getActiveProvinciaPicklistValues() {
        Set<String> values = new Set<String>();
        Schema.DescribeFieldResult dfr = ATV_NTS_Direccion_de_Envio__c.ATV_NTS_Provincia__c.getDescribe();
        if (dfr.getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry p : dfr.getPicklistValues()) {
                if (p.isActive()) {
                    values.add(p.getValue());
                }
            }
        }
        return values;
    }

    private static String normalizeKey(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        String v = input.trim().toUpperCase();
        v = v
            .replace('Á', 'A')
            .replace('É', 'E')
            .replace('Í', 'I')
            .replace('Ó', 'O')
            .replace('Ú', 'U')
            .replace('Ü', 'U')
            .replace('Ñ', 'N');
        v = v.replaceAll('[^A-Z0-9 ]', ' ');
        v = v.replaceAll('\\s+', ' ').trim();
        return v;
    }
}