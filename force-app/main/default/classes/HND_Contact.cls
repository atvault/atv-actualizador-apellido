public class HND_Contact {

    /* ─────────────────────────────────────────────────────────────────────
       NAMESPACES 2022.2 – SuiteTalk
       ─────────────────────────────────────────────────────────────────────*/
    private static final String ENV_NS        = 'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String XSI_NS        = 'http://www.w3.org/2001/XMLSchema-instance';
    private static final String PLATFORM_CORE = 'urn:core_2022_2.platform.webservices.netsuite.com';
    private static final String PLATFORM_MSGS = 'urn:messages_2022_2.platform.webservices.netsuite.com';
    private static final String REL_NS        = 'urn:relationships_2022_2.lists.webservices.netsuite.com';

    /**
     * Entrada desde trigger: detecta cambios y encola creación/actualización.
     */
    public static void sendContactToNetSuite(List<Contact> contacts, Map<Id,Contact> oldMap) {
        List<Id> toCreate = new List<Id>(), toUpdate = new List<Id>();
        for (Contact c : contacts) {
            if (!c.Carga_Inicial__c) {
                Boolean changed = oldMap == null
                    || c.FirstName            != oldMap.get(c.Id).FirstName
                    || c.LastName             != oldMap.get(c.Id).LastName
                    || c.Email                != oldMap.get(c.Id).Email
                    || c.Phone                != oldMap.get(c.Id).Phone
                    || c.MobilePhone          != oldMap.get(c.Id).MobilePhone
                    || c.Title                != oldMap.get(c.Id).Title
                    || c.Salutation           != oldMap.get(c.Id).Salutation
                    || c.Puesto_de_Trabajo__c != oldMap.get(c.Id).Puesto_de_Trabajo__c;
                if (changed) {
                    if (c.ID_NetSuite__c == null) toCreate.add(c.Id);
                    else                          toUpdate.add(c.Id);
                }
            }
        }
        for (Id cid : toCreate)  createContact(cid);
        if (!toUpdate.isEmpty()) updateContact(toUpdate);
    }

    /**
     * @future(callout=true)
     * Crea un **Contact** en NetSuite, incluyendo todos los campos requeridos.
     */
    @future(callout=true)
    public static void createContact(Id contactId) {
        Contact c = [
            SELECT FirstName, LastName, Email, Phone, MobilePhone,
                   Salutation, Title, Puesto_de_Trabajo__c,
                   Account.Id_NetSuite__c
            FROM Contact WHERE Id = :contactId
        ];
        NetSuite_Credential__mdt cred = HLP_NetSuiteCallout.getCredentials();
        Dom.Document doc = new Dom.Document();

        // 1) Envelope + Header
        Dom.XmlNode env = HLP_NetSuiteCallout.createHeader(doc, '');
        env.setNamespace('platformCore', PLATFORM_CORE);
        env.setNamespace('platformMsgs', PLATFORM_MSGS);
        env.setNamespace('listRel',      REL_NS);

        // 2) Body / <platformMsgs:add>
        Dom.XmlNode body = env.addChildElement('Body', ENV_NS, null);
        Dom.XmlNode add  = body.addChildElement('add', PLATFORM_MSGS, 'platformMsgs');

        // 3) <platformMsgs:record xsi:type="listRel:Contact">
        Dom.XmlNode rec = add.addChildElement('record', PLATFORM_MSGS, 'platformMsgs');
        rec.setAttribute('xmlns:xsi', XSI_NS);
        rec.setAttribute('xsi:type',  'listRel:Contact');

        //    • Vinculación al Account (company)
        if (c.Account != null && c.Account.Id_NetSuite__c != null) {
            rec.addChildElement('company', REL_NS, 'listRel')
               .setAttribute('internalId', String.valueOf(c.Account.Id_NetSuite__c));
        }

        //    • Campos requeridos
        if (c.Salutation != null) {
            rec.addChildElement('salutation', REL_NS, 'listRel')
               .addTextNode(c.Salutation);
        }
        // Reemplaza '5' por el internalId real de tu Contact Role en NetSuite
        rec.addChildElement('contactRole', REL_NS, 'listRel')
           .setAttribute('internalId', '5');
        if (c.Title != null) {
            rec.addChildElement('title', REL_NS, 'listRel')
               .addTextNode(c.Title);
        }
        if (c.Email != null) {
            rec.addChildElement('email', REL_NS, 'listRel')
               .addTextNode(c.Email);
        }
        if (c.Phone != null) {
            rec.addChildElement('phone', REL_NS, 'listRel')
               .addTextNode(c.Phone);
        }

        // 4) Envío y manejo de respuesta
        HttpResponse resp = HLP_NetSuiteCallout.sendRequest(doc, cred.URL__c, 'add');
        if (resp.getStatusCode() == 200) {
            String nsId = HLP_NetSuiteCallout.processResponse(resp.getBodyDocument(), 'add');
            if (nsId != null) {
                c.ID_NetSuite__c = nsId;
                Database.update(c, false);
            }
        } else {
            System.debug('Error crear Contact en NS: ' + resp.getBody());
        }
    }

    /**
     * @future(callout=true)
     * Actualiza un **Contact** en NetSuite vía <updateList>, incluyendo los mismos campos.
     */
    @future(callout=true)
    public static void updateContact(List<Id> ids) {
        List<Contact> listC = [
            SELECT Id, ID_NetSuite__c,
                   Salutation, Title, Email, Phone,
                   Account.Id_NetSuite__c
            FROM Contact WHERE Id IN :ids
        ];
        NetSuite_Credential__mdt cred = HLP_NetSuiteCallout.getCredentials();
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode env = HLP_NetSuiteCallout.createHeader(doc, '');
        env.setNamespace('platformCore', PLATFORM_CORE);
        env.setNamespace('platformMsgs', PLATFORM_MSGS);
        env.setNamespace('listRel',      REL_NS);

        Dom.XmlNode body = env.addChildElement('Body', ENV_NS, null);
        Dom.XmlNode upd  = body.addChildElement('updateList', PLATFORM_MSGS, 'platformMsgs');

        for (Contact c : listC) {
            Dom.XmlNode rec = upd.addChildElement('record', PLATFORM_MSGS, 'platformMsgs');
            rec.setAttribute('xmlns:xsi', XSI_NS);
            rec.setAttribute('xsi:type',  'listRel:Contact');
            rec.setAttribute('internalId', c.ID_NetSuite__c);

            if (c.Account != null && c.Account.Id_NetSuite__c != null) {
                rec.addChildElement('company', REL_NS, 'listRel')
                   .setAttribute('internalId', String.valueOf(c.Account.Id_NetSuite__c));
            }
            if (c.Salutation != null) rec.addChildElement('salutation', REL_NS, 'listRel').addTextNode(c.Salutation);
            rec.addChildElement('contactRole', REL_NS, 'listRel').setAttribute('internalId', '5');
            if (c.Title      != null) rec.addChildElement('title',       REL_NS, 'listRel').addTextNode(c.Title);
            if (c.Email      != null) rec.addChildElement('email',       REL_NS, 'listRel').addTextNode(c.Email);
            if (c.Phone      != null) rec.addChildElement('phone',       REL_NS, 'listRel').addTextNode(c.Phone);
        }

        HttpResponse resp = HLP_NetSuiteCallout.sendRequest(doc, cred.URL__c, 'updateList');
        if (resp.getStatusCode() == 200) {
            HLP_NetSuiteCallout.processResponse(resp.getBodyDocument(), 'updateList');
        } else {
            System.debug('Error actualizar Contact en NS: ' + resp.getBody());
        }
    }
}