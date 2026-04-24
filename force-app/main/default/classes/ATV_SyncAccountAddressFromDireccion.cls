/**
 * Sincroniza Shipping* y Billing* de Account desde registros de ATV_NTS_Direccion_de_Envio__c
 * marcados como predeterminados (mismo criterio que los flows de Quote).
 */
public with sharing class ATV_SyncAccountAddressFromDireccion {
    public class SyncResult {
        @AuraEnabled public Integer accountIdsToTouch;
        @AuraEnabled public Integer updatedOk;
        @AuraEnabled public Integer updatedErrors;
    }

    /**
     * @param doCommit false = solo calcula cuentas a tocar, sin DML
     */
    public static SyncResult sync(Boolean doCommit) {
        SyncResult res = new SyncResult();
        Map<Id, ATV_NTS_Direccion_de_Envio__c> shipByAcc = loadShippingDefaults();
        Map<Id, ATV_NTS_Direccion_de_Envio__c> billByAcc = loadBillingDefaults();

        Set<Id> accIds = new Set<Id>();
        accIds.addAll(shipByAcc.keySet());
        accIds.addAll(billByAcc.keySet());
        res.accountIdsToTouch = accIds.size();

        if (accIds.isEmpty() || !doCommit) {
            res.updatedOk = 0;
            res.updatedErrors = 0;
            return res;
        }

        List<Account> toUpdate = new List<Account>();
        for (Id accId : accIds) {
            Account a = new Account(Id = accId);
            if (shipByAcc.containsKey(accId)) {
                applyShipping(a, shipByAcc.get(accId));
            }
            if (billByAcc.containsKey(accId)) {
                applyBilling(a, billByAcc.get(accId));
            }
            toUpdate.add(a);
        }

        Database.SaveResult[] srs = Database.update(toUpdate, false);
        Integer ok = 0;
        Integer ko = 0;
        for (Database.SaveResult sr : srs) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                ko++;
            }
        }
        res.updatedOk = ok;
        res.updatedErrors = ko;
        return res;
    }

    private static Map<Id, ATV_NTS_Direccion_de_Envio__c> loadShippingDefaults() {
        Map<Id, ATV_NTS_Direccion_de_Envio__c> m = new Map<Id, ATV_NTS_Direccion_de_Envio__c>();
        List<ATV_NTS_Direccion_de_Envio__c> rows = [
            SELECT
                Account__c,
                LastModifiedDate,
                NTS_fld_ShippingStreet__c,
                NTS_fld_ShippingCity__c,
                ATV_fld_ShippingPostalCode__c,
                NTS_fld_ShippingCountry__c,
                ATV_NTS_Provincia__c,
                ATV_NTS_Localidad__r.Name
            FROM ATV_NTS_Direccion_de_Envio__c
            WHERE Direccion_predeterminada__c = TRUE AND Account__c != NULL
            ORDER BY Account__c, LastModifiedDate DESC, Id DESC
        ];
        for (ATV_NTS_Direccion_de_Envio__c d : rows) {
            if (!m.containsKey(d.Account__c)) {
                m.put(d.Account__c, d);
            }
        }
        return m;
    }

    private static Map<Id, ATV_NTS_Direccion_de_Envio__c> loadBillingDefaults() {
        Map<Id, ATV_NTS_Direccion_de_Envio__c> m = new Map<Id, ATV_NTS_Direccion_de_Envio__c>();
        List<ATV_NTS_Direccion_de_Envio__c> rows = [
            SELECT
                Account__c,
                LastModifiedDate,
                NTS_fld_ShippingStreet__c,
                NTS_fld_ShippingCity__c,
                ATV_fld_ShippingPostalCode__c,
                NTS_fld_ShippingCountry__c,
                ATV_NTS_Provincia__c,
                ATV_NTS_Localidad__r.Name
            FROM ATV_NTS_Direccion_de_Envio__c
            WHERE Direccion_predeterminada_facturacion__c = TRUE AND Account__c != NULL
            ORDER BY Account__c, LastModifiedDate DESC, Id DESC
        ];
        for (ATV_NTS_Direccion_de_Envio__c d : rows) {
            if (!m.containsKey(d.Account__c)) {
                m.put(d.Account__c, d);
            }
        }
        return m;
    }

    @TestVisible
    private static void applyShipping(Account a, ATV_NTS_Direccion_de_Envio__c d) {
        a.ShippingStreet = d.NTS_fld_ShippingStreet__c;
        a.ShippingCity = cityFromDireccion(d);
        a.ShippingState = d.ATV_NTS_Provincia__c;
        a.ShippingPostalCode = d.ATV_fld_ShippingPostalCode__c;
        a.ShippingCountry = d.NTS_fld_ShippingCountry__c;
    }

    @TestVisible
    private static void applyBilling(Account a, ATV_NTS_Direccion_de_Envio__c d) {
        a.BillingStreet = d.NTS_fld_ShippingStreet__c;
        a.BillingCity = cityFromDireccion(d);
        a.BillingState = d.ATV_NTS_Provincia__c;
        a.BillingPostalCode = d.ATV_fld_ShippingPostalCode__c;
        a.BillingCountry = d.NTS_fld_ShippingCountry__c;
    }

    /** Ciudad = nombre de Localidad si existe; si no, campo ciudad de la dirección (complemento al flow). */
    private static String cityFromDireccion(ATV_NTS_Direccion_de_Envio__c d) {
        if (d.ATV_NTS_Localidad__r != null && String.isNotBlank(d.ATV_NTS_Localidad__r.Name)) {
            return d.ATV_NTS_Localidad__r.Name;
        }
        return d.NTS_fld_ShippingCity__c;
    }
}