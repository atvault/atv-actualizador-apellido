public class HND_Account {

    /* ────────────────────────────────
       NAMESPACES 2022.2 – SuiteTalk
       ──────────────────────────────── */
    private static final String ENV_NS   = 'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String XSI_NS   = 'http://www.w3.org/2001/XMLSchema-instance';
    private static final String CORE_NS  = 'urn:core_2022_2.platform.webservices.netsuite.com';
    private static final String MSGS_NS  = 'urn:messages_2022_2.platform.webservices.netsuite.com';
    private static final String REL_NS   = 'urn:relationships_2022_2.lists.webservices.netsuite.com';

    /* ═══════════════════════════════════════════════════════════════════════
       MÉTODO PARA DETECTAR CAMBIOS RELEVANTES
       ====================================================================== */
    public static Boolean hasRelevantChanges(Account a, Account o) {
        return a.Name                      != o.Name  ||
               a.Phone                     != o.Phone ||
               a.Email__c                  != o.Email__c ||
               a.Rubro__c                  != o.Rubro__c ||
               a.BillingStreet             != o.BillingStreet ||
               a.CUIT__c                   != o.CUIT__c ||
               a.Tipo_de_Contribuyente__c  != o.Tipo_de_Contribuyente__c ||
               a.Cat__c                    != o.Cat__c ||
               a.Estado__c                 != o.Estado__c ||
               a.OwnerId                   != o.OwnerId;
    }

    /* ═══════════════════════════════════════════════════════════════════════
       MÉTODOS PUENTE (sincrónico / @future)
       ====================================================================== */
    public static void sendAccountToNetSuiteAsync(Set<Id> accountIds,
                                                  Boolean overrideFlag) {

        List<Account> acctList = [
            SELECT Id, Name, Phone, Email__c, OwnerId,
                   ID_NetSuite__c, EstadoEnNetsuite__c,
                   Cat__c, Rubro__c, Carga_Inicial__c,
                   Tipo_de_Contribuyente__c, CUIT__c, Estado__c, Website
            FROM Account
            WHERE Id IN :accountIds
        ];
        sendAccountToNetSuite(acctList, null);
    }

    public static void sendAccountToNetSuite(List<Account> accounts,
                                             Map<Id, Account> oldMap,
                                             Boolean overrideFlag) {
        sendAccountToNetSuite(accounts, oldMap);   // overrideFlag reservado
    }

    public static void sendAccountToNetSuite(List<Account> accounts,
                                              Map<Id, Account> oldMap) {

        List<Id> toCreate = new List<Id>();
        List<Id> toUpdate = new List<Id>();

        for (Account acc : accounts) {
            Boolean shouldSync =
                  !acc.Carga_Inicial__c
              &&  acc.Email__c != null
              &&  acc.Phone    != null
              &&  acc.CUIT__c  != null
              && (oldMap == null
                  || (oldMap.containsKey(acc.Id)
                      && hasRelevantChanges(acc, oldMap.get(acc.Id))));
            if (shouldSync) {
                if (acc.ID_NetSuite__c == null)  toCreate.add(acc.Id);
                else                              toUpdate.add(acc.Id);
            }
        }
        for (Id idAcc : toCreate)  createCustomer(idAcc);
        if (!toUpdate.isEmpty())   updateCustomer(toUpdate);

        /* reset Carga_Inicial__c */
        List<Account> reset = [SELECT Id, Carga_Inicial__c
                               FROM Account WHERE Carga_Inicial__c = true];
        for (Account a : reset) a.Carga_Inicial__c = false;
        if (!reset.isEmpty()) Database.update(reset, false);
    }

    /* ═══════════════════════════════════════════════════════════════════════
       @future – ADD
       ====================================================================== */
    @future(callout=true)
    public static void createCustomer(Id idCuenta) {

        Account acc = [
            SELECT Id, Name, Phone, Email__c, CUIT__c,
                   BillingStreet, BillingCity, BillingState,
                   BillingCountry, BillingPostalCode,
                   ID_NetSuite__c, Rubro__c, Cat__c,
                   Tipo_de_Contribuyente__c,Website,Estado__c, OwnerId
            FROM Account WHERE Id = :idCuenta
        ];

        NetSuite_Credential__mdt cred = HLP_NetSuiteCallout.getCredentials();
        Dom.Document doc = new Dom.Document();

        /* Envelope + TokenPassport */
        Dom.XmlNode env = HLP_NetSuiteCallout.createHeader(doc, '');
        env.setNamespace('platformCore', CORE_NS);
        env.setNamespace('platformMsgs', MSGS_NS);
        env.setNamespace('entity',       REL_NS);

        Dom.XmlNode body = env.addChildElement('Body', ENV_NS, 'soapenv');

        Dom.XmlNode add = body.addChildElement('add', MSGS_NS, 'platformMsgs');
        add.setAttribute('xsi:type', 'platformMsgs:AddRequest');

        createBody(add, acc);

        HttpResponse resp = HLP_NetSuiteCallout.sendRequest(doc, cred.URL__c, 'add');
        if (resp.getStatusCode() == 200) {
            String idNS = HLP_NetSuiteCallout.processResponse(resp.getBodyDocument(), 'add');
            if (idNS != null && idNS.isNumeric()) {
                acc.ID_NetSuite__c = Integer.valueOf(idNS);
                Database.update(acc, false);
            }
        }
    }

    /* ═══════════════════════════════════════════════════════════════════════
       @future – UPDATE
       ====================================================================== */
    @future(callout=true)
    public static void updateCustomer(List<Id> ids) {

        List<Account> listAcc = [
            SELECT Id, Name, Phone, Email__c, CUIT__c,
                   BillingStreet, BillingCity, BillingState,
                   BillingCountry, BillingPostalCode,
                   ID_NetSuite__c, Rubro__c, Cat__c,
                   Tipo_de_Contribuyente__c, Website, Estado__c, OwnerId
            FROM Account WHERE Id IN :ids
        ];

        NetSuite_Credential__mdt cred = HLP_NetSuiteCallout.getCredentials();
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode env = HLP_NetSuiteCallout.createHeader(doc, '');
        env.setNamespace('platformCore', CORE_NS);
        env.setNamespace('platformMsgs', MSGS_NS);
        env.setNamespace('entity',       REL_NS);

        Dom.XmlNode body = env.addChildElement('Body', ENV_NS, 'soapenv');

        Dom.XmlNode upd = body.addChildElement('updateList', MSGS_NS, 'platformMsgs');
        upd.setAttribute('xsi:type','platformMsgs:UpdateListRequest');

        for (Account acc : listAcc) createBody(upd, acc);

        HttpResponse resp = HLP_NetSuiteCallout.sendRequest(doc, cred.URL__c, 'updateList');
        if (resp.getStatusCode() == 200) {
            HLP_NetSuiteCallout.processResponse(resp.getBodyDocument(), 'updateList');
        }
    }

    /* ═══════════════════════════════════════════════════════════════════════
       BUILD RECORD (Customer)
       ====================================================================== */
    private static Dom.XmlNode createBody(Dom.XmlNode dmlNode, Account cuenta) {

        User usr = [SELECT Id_NetSuite__c FROM User WHERE Id = :cuenta.OwnerId LIMIT 1];

        /* record – xsi:type */
        Dom.XmlNode recordNode = dmlNode.addChildElement('record', null, null);
        recordNode.setAttribute('xsi:type', 'entity:Customer');
        if (cuenta.ID_NetSuite__c != null)
            recordNode.setAttribute('internalId', String.valueOf(cuenta.ID_NetSuite__c));

        /* ─── Campos estándar (prefijo entity) ─── */
        recordNode.addChildElement('subsidiary',  REL_NS, 'entity')
                  .setAttribute('internalId','1');
        recordNode.addChildElement('companyName', REL_NS, 'entity')
                  .addTextNode(cuenta.Name);
        if (cuenta.CUIT__c != null)
            recordNode.addChildElement('vatRegNumber', REL_NS, 'entity')
                      .addTextNode(String.valueOf(cuenta.CUIT__c));
        if (cuenta.Phone != null)
            recordNode.addChildElement('phone', REL_NS, 'entity')
                      .addTextNode(cuenta.Phone);
        if (cuenta.Email__c != null)
            recordNode.addChildElement('email', REL_NS, 'entity')
                      .addTextNode(cuenta.Email__c);
        if (cuenta.Cat__c != null)
            recordNode.addChildElement('category', REL_NS, 'entity')
                      .setAttribute('internalId', cuenta.Cat__c);
                if (cuenta.Website != null)
            recordNode.addChildElement('url', REL_NS, 'entity')
                      .setAttribute('internalId', cuenta.Website);
        
    if (cuenta.Estado__c != null) {
        // Asegurate de haber declarado antes: env.setNamespace('listRel', REL_NS);
        Dom.XmlNode statusNode = recordNode.addChildElement('entityStatus', REL_NS, 'listRel');
        statusNode.setAttribute('internalId', cuenta.Estado__c);
    }

        /* ─── Sales Team List (relationships) ─── */
/*
        if (usr.Id_NetSuite__c != null) {
            Dom.XmlNode stList = recordNode.addChildElement('salesTeamList', REL_NS, 'entity');
            stList.setAttribute('replaceAll','T');

            Dom.XmlNode st  = stList.addChildElement('salesTeam', REL_NS, 'entity');
            Dom.XmlNode emp = st.addChildElement('employee', REL_NS, 'entity');
            emp.setAttribute('internalId', usr.Id_NetSuite__c);

            st.addChildElement('contribution', REL_NS, 'entity').addTextNode('100.0');
            st.addChildElement('isPrimary',    REL_NS, 'entity').addTextNode('T');
st.addChildElement('salesRole',    REL_NS, 'entity').addTextNode('2');
        }
*/
        /* ─── CustomFieldList (entity, type = platformCore) ─── */
        Dom.XmlNode cfl = recordNode.addChildElement('customFieldList', REL_NS, 'entity');
        cfl.setAttribute('xsi:type','platformCore:CustomFieldList');

        /* Rubro */
        Dom.XmlNode cfR = cfl.addChildElement('customField', CORE_NS, 'platformCore');
        cfR.setAttribute('xsi:type','platformCore:SelectCustomFieldRef');
        cfR.setAttribute('scriptId','custentity_3k_rubro_cliente');
        cfR.addChildElement('value', CORE_NS, 'platformCore')
            .setAttribute('internalId',
                String.isNotBlank(cuenta.Rubro__c) ? cuenta.Rubro__c : '43');

        /* Salesforce Id */
        Dom.XmlNode cfSF = cfl.addChildElement('customField', CORE_NS, 'platformCore');
        cfSF.setAttribute('xsi:type','platformCore:StringCustomFieldRef');
        cfSF.setAttribute('scriptId','custentity10');
        cfSF.addChildElement('value', CORE_NS, 'platformCore').addTextNode(cuenta.Id);

        /* Nombre legal */
        Dom.XmlNode cfNL = cfl.addChildElement('customField', CORE_NS, 'platformCore');
        cfNL.setAttribute('xsi:type','platformCore:StringCustomFieldRef');
        cfNL.setAttribute('scriptId','custentity_l54_nombre_legal');
        cfNL.addChildElement('value', CORE_NS, 'platformCore').addTextNode(cuenta.Name);

        /* CUIT entity */
        Dom.XmlNode cfCU = cfl.addChildElement('customField', CORE_NS, 'platformCore');
        cfCU.setAttribute('xsi:type','platformCore:StringCustomFieldRef');
        cfCU.setAttribute('scriptId','custentity_l54_cuit_entity');
        cfCU.addChildElement('value', CORE_NS, 'platformCore')
            .addTextNode(String.valueOf(cuenta.CUIT__c));

        /* Tipo documento */
        Dom.XmlNode cfTD = cfl.addChildElement('customField', CORE_NS, 'platformCore');
        cfTD.setAttribute('xsi:type','platformCore:SelectCustomFieldRef');
        cfTD.setAttribute('scriptId','custentity_l54_tipo_documento');
        cfTD.addChildElement('value', CORE_NS, 'platformCore')
             .setAttribute('internalId','3');

        /* Tipo contribuyente */
        Dom.XmlNode cfTC = cfl.addChildElement('customField', CORE_NS, 'platformCore');
        cfTC.setAttribute('xsi:type','platformCore:SelectCustomFieldRef');
        cfTC.setAttribute('scriptId','custentity_l54_tipo_contribuyente');
        cfTC.addChildElement('value', CORE_NS, 'platformCore')
             .setAttribute('internalId',
                Constants.TIPO_CONTRIBUYENTE.containsKey(cuenta.Tipo_de_Contribuyente__c)
                ? Constants.TIPO_CONTRIBUYENTE.get(cuenta.Tipo_de_Contribuyente__c)
                : '9');

        return recordNode;
    }
}