public class HND_Quote {

    /*───────────────── SuiteTalk 2022.2 namespaces ─────────────────*/
    private static final String ENV_NS   = 'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String MSGS_NS  = 'urn:messages_2022_2.platform.webservices.netsuite.com';
    private static final String SALES_NS = 'urn:sales_2022_2.transactions.webservices.netsuite.com';
    private static final String COMM_NS  = 'urn:common_2022_2.platform.webservices.netsuite.com';
    private static final String CORE_NS  = 'urn:core_2022_2.platform.webservices.netsuite.com';

    /*──────── trigger entry point ────────*/
    public static void sendQuoteToNetSuite(List<Quote> qs, Map<Id,Quote> oldMap){
        for (Quote q : qs)
            if (q.Status!=oldMap.get(q.Id).Status && q.Status=='Accepted' && q.Pedido__c==null)
                createQuote(q.Id);
    }

    /*──────── @future callout ────────────*/
    @future(callout=true)
    public static void createQuote(Id quoteId){

        Quote quote = [SELECT Id, Account.ID_Netsuite__c, BillingStreet, BillingPostalCode
                       FROM Quote WHERE Id=:quoteId];

        List<QuoteLineItem> items = [SELECT Product2.NTS_fld_internalIdNTS__c,
                                            Quantity, UnitPrice, TotalPrice
                                     FROM   QuoteLineItem
                                     WHERE  QuoteId=:quoteId];

        NetSuite_Credential__mdt cred = HLP_NetSuiteCallout.getCredentials();

        /* envelope + header */
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode env  = HLP_NetSuiteCallout.createHeader(doc,'SalesOrder');
        env.setNamespace('platformMsgs', MSGS_NS);
        env.setNamespace('tranSales'   , SALES_NS);
        env.setNamespace('common'      , COMM_NS);
        env.setNamespace('platformCore', CORE_NS);

        /* body / add */
        Dom.XmlNode body = env.addChildElement('Body', ENV_NS, null);
        Dom.XmlNode add  = body.addChildElement('add', MSGS_NS, 'platformMsgs');
        add.setAttribute('xsi:type','platformMsgs:AddRequest');

        buildSalesOrder(add, quote, items);

        /* envío */
        HttpResponse res = HLP_NetSuiteCallout.sendRequest(doc, cred.URL__c, 'add');
        if (res.getStatusCode()==200)
            HLP_NetSuiteCallout.processResponse(res.getBodyDocument(),'add');
        else
            System.debug(res.getBody());
    }

    /*──────── helpers para CFs ─────────*/
    private static Dom.XmlNode addStringCF(Dom.XmlNode p,String script,String val){
        Dom.XmlNode cf = p.addChildElement('customField', CORE_NS,'platformCore');
        cf.setAttribute('xsi:type','platformCore:StringCustomFieldRef');
        cf.setAttribute('scriptId',script);
        cf.addChildElement('value', CORE_NS,'platformCore').addTextNode(val);
        return cf;
    }
    private static Dom.XmlNode addSelectCF(Dom.XmlNode p,String script,String id){
        Dom.XmlNode cf = p.addChildElement('customField', CORE_NS,'platformCore');
        cf.setAttribute('xsi:type','platformCore:SelectCustomFieldRef');
        cf.setAttribute('scriptId',script);
        cf.addChildElement('value', CORE_NS,'platformCore').setAttribute('internalId',id);
        return cf;
    }

    /*──────── construye el SalesOrder ────────*/
    private static void buildSalesOrder(Dom.XmlNode addNode, Quote q, List<QuoteLineItem> items){

        Dom.XmlNode rec = addNode.addChildElement('record', MSGS_NS,'platformMsgs');
        rec.setAttribute('xsi:type','tranSales:SalesOrder');

        rec.addChildElement('tranDate', SALES_NS,'tranSales')
           .addTextNode(Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss'));
        rec.addChildElement('status', SALES_NS,'tranSales').addTextNode('Pending Approval');
        rec.addChildElement('entity', SALES_NS,'tranSales')
           .setAttribute('internalId', String.valueOf(q.Account.ID_Netsuite__c));

        /*── NUEVO: nodo class como RecordRef ──*/
        Dom.XmlNode classNode = rec.addChildElement('class', SALES_NS,'tranSales');
        classNode.setNamespace('core', CORE_NS);               // alias "core" → CORE_NS
        classNode.setAttribute('xsi:type', 'core:RecordRef');  // tipo correcto
        classNode.setAttribute('internalId', '4');             // id válido de Clase

        rec.addChildElement('externalId', SALES_NS,'tranSales').addTextNode('SF-'+q.Id);
        rec.addChildElement('taxDetailsOverride', SALES_NS,'tranSales').addTextNode('true');

        /*── customFieldList de CABECERA  ──*/
        Dom.XmlNode cfl = rec.addChildElement('customFieldList', SALES_NS,'tranSales');
        cfl.setAttribute('xsi:type','platformCore:CustomFieldList');
        addSelectCF(cfl,'custbody_3k_lista_transportista','5112');
        addSelectCF(cfl,'custbody_3k_unidad_negocio','1');
        addStringCF(cfl,'custbody_tipo_orden','Internacional');

        /*── Dirección ─────────────────────*/
        Dom.XmlNode addr = rec.addChildElement('billingAddress', SALES_NS,'tranSales');
        addr.setAttribute('xsi:type','common:Address');
        addr.addChildElement('country', COMM_NS,'common').addTextNode('_argentina');
        if(q.BillingStreet!=null)
            addr.addChildElement('addr1', COMM_NS,'common').addTextNode(q.BillingStreet);
        if(q.BillingPostalCode!=null)
            addr.addChildElement('zip', COMM_NS,'common').addTextNode(q.BillingPostalCode);

        Dom.XmlNode addrCfl = addr.addChildElement('customFieldList', COMM_NS,'common');
        addrCfl.setAttribute('xsi:type','platformCore:CustomFieldList');
        addSelectCF(addrCfl,'custrecordloccui','7128');
        addSelectCF(addrCfl,'custrecord_l54_provincia','25');

        /*── itemList ──────────────────────*/
        Dom.XmlNode itemList = rec.addChildElement('itemList', SALES_NS,'tranSales');
        itemList.setAttribute('xsi:type','tranSales:SalesOrderItemList');

        for (QuoteLineItem it : items){
            Dom.XmlNode itNode = itemList.addChildElement('item', SALES_NS,'tranSales');
            itNode.setAttribute('xsi:type','tranSales:SalesOrderItem');

            itNode.addChildElement('item', SALES_NS,'tranSales')
                  .setAttribute('internalId', it.Product2.NTS_fld_internalIdNTS__c);
            itNode.addChildElement('quantity', SALES_NS,'tranSales')
                  .addTextNode(String.valueOf(it.Quantity));
            itNode.addChildElement('rate', SALES_NS,'tranSales')
                  .addTextNode(String.valueOf(it.UnitPrice));
            itNode.addChildElement('amount', SALES_NS,'tranSales')
                  .addTextNode(String.valueOf(it.TotalPrice));

            Dom.XmlNode itCfl = itNode.addChildElement('customFieldList', SALES_NS,'tranSales');
            itCfl.setAttribute('xsi:type','platformCore:CustomFieldList');
            addStringCF(itCfl,'custcol_origen_item','Importado');
        }
    }
}