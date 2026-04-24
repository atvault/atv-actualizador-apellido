public class HLP_NetSuiteCallout {
    @TestVisible static Boolean overrideIsSandbox;

    public static NetSuite_Credential__mdt getCredentials() {
        Boolean isSandbox = (Test.isRunningTest() && overrideIsSandbox != null)
                             ? overrideIsSandbox
                             : [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        System.debug('💡 getCredentials: isSandbox=' + isSandbox);
        
        NetSuite_Credential__mdt credential = [
            SELECT Account__c, Consumer_Key__c, Consumer_Secret__c,
                   Token_Id__c, Token_Secret__c, URL__c
            FROM NetSuite_Credential__mdt
            WHERE DeveloperName = : (isSandbox ? 'UAT' : 'Produccion')
            LIMIT 1
        ];
        System.debug('💡 getCredentials: fetched credential: ' + credential.Account__c);
        return credential;
    }

    public static Dom.XmlNode createHeader(Dom.Document doc, String reqType) {
        System.debug('💡 createHeader called with reqType=' + reqType);
        NetSuite_Credential__mdt cred = getCredentials();
        System.debug('💡 createHeader: using Account=' + cred.Account__c);

        String soapenv = 'http://schemas.xmlsoap.org/soap/envelope/';
        Dom.XmlNode env = doc.createRootElement('Envelope', soapenv, 'soapenv');
        env.setNamespace('ns1','urn:sales_2022_2.transactions.webservices.netsuite.com');
        env.setNamespace('ns2','urn:common_2022_2.platform.webservices.netsuite.com');
        env.setNamespace('ns3','urn:core_2022_2.platform.webservices.netsuite.com');
        env.setNamespace('ns4','urn:messages_2022_2.platform.webservices.netsuite.com');
        env.setNamespace('ns5','ns');
        env.setNamespace('xsi','http://www.w3.org/2001/XMLSchema-instance');
        env.setNamespace('ns6','urn:messages_2022_2.platform.webservices.netsuite.com');
        env.setNamespace('ns7','urn:customization_2022_2.setup.webservices.netsuite.com');
        env.setNamespace('entity', reqType=='SalesOrder1'
                          ? 'urn:sales_2022_2.transactions.webservices.netsuite.com'
                          : 'urn:relationships_2022_2.lists.webservices.netsuite.com');

        String timestamp = String.valueOf(System.currentTimeMillis()/1000);
        String nonce = EncodingUtil.base64Encode(Crypto.generateAesKey(128)).substring(0,10);
        String base = cred.Account__c + '&' + cred.Consumer_Key__c + '&' +
                      cred.Token_Id__c + '&' + nonce + '&' + timestamp;
        String key = cred.Consumer_Secret__c + '&' + cred.Token_Secret__c;
        String sig = EncodingUtil.base64Encode(
                        Crypto.generateMac('HmacSHA256', Blob.valueOf(base), Blob.valueOf(key))
                     );

        Dom.XmlNode hdr = env.addChildElement('Header', soapenv, null);
        Dom.XmlNode tp = hdr.addChildElement('ns5:tokenPassport', null, null);
        tp.setAttribute('xsi:type','ns3:TokenPassport');
        tp.addChildElement('ns3:account', null, null).addTextNode(cred.Account__c);
        tp.addChildElement('ns3:consumerKey', null, null).addTextNode(cred.Consumer_Key__c);
        tp.addChildElement('ns3:token', null, null).addTextNode(cred.Token_Id__c);
        tp.addChildElement('ns3:nonce', null, null).addTextNode(nonce);
        tp.addChildElement('ns3:timestamp', null, null).addTextNode(timestamp);
        Dom.XmlNode sd = tp.addChildElement('ns3:signature', null, null);
        sd.setAttribute('algorithm','HMAC-SHA256');
        sd.addTextNode(sig);

        System.debug('💡 createHeader: SOAP header XML: ' + doc.toXmlString());
        return env;
    }

    public static HttpResponse sendRequest(Dom.Document doc, String url, String reqType) {
        System.debug('💡 sendRequest: endpoint=' + url + ', reqType=' + reqType);
        HttpRequest r = new HttpRequest();
        r.setEndpoint(url);
        r.setMethod('POST');
        r.setHeader('SOAPAction', reqType);
        r.setBody(doc.toXmlString());
        r.setTimeout(120000);
        HttpResponse resp = new Http().send(r);
        System.debug('💡 sendRequest: Status=' + resp.getStatusCode());
        System.debug('💡 sendRequest: Body=' + resp.getBody());
        return resp;
    }

    public static String processResponse(Dom.Document document, String reqType) {
        System.debug('🔍 processResponse start reqType=' + reqType);
        Dom.XmlNode root = document.getRootElement();
        System.debug('🔍 root name=' + root.getName() + ', ns=' + root.getNamespace());

        Dom.XmlNode body = root.getChildElement('Body','http://schemas.xmlsoap.org/soap/envelope/');
        if (body == null) {
            System.debug('❌ No <Body>');
            return null;
        }
        System.debug('🔍 found Body, children count=' + body.getChildElements().size());

        String responseName = reqType=='updateList' ? 'updateListResponse' : reqType+'Response';
        Dom.XmlNode resp;
        for (Dom.XmlNode c: body.getChildElements()) {
            System.debug('🔍 Body child: ' + c.getName() + ', ns=' + c.getNamespace());
            if (c.getName().endsWith(responseName)) {
                resp = c;
                break;
            }
        }
        if (resp == null) {
            System.debug('❌ No <'+responseName+'>');
            return null;
        }
        System.debug('✅ found response node: '+resp.getName());

        Dom.XmlNode wr = resp.getChildElement(
            reqType=='updateList' ? 'writeResponseList' : 'writeResponse',
            'urn:messages_2022_2.platform.webservices.netsuite.com'
        );
        if (wr == null) {
            System.debug('❌ No writeResponse/writeResponseList');
            return null;
        }
        System.debug('🔍 found writeResponse node');

        Dom.XmlNode br;
        if (reqType=='updateList') {
            List<Dom.XmlNode> wrs = wr.getChildElements();
            if (wrs.isEmpty()) {
                System.debug('❌ writeResponseList vacío');
                return null;
            }
            br = wrs[0].getChildElement('baseRef','urn:messages_2022_2.platform.webservices.netsuite.com');
        } else {
            br = wr.getChildElement('baseRef','urn:messages_2022_2.platform.webservices.netsuite.com');
        }

        if (br == null) {
            System.debug('❌ No baseRef encontrado');
            return null;
        }
        String id = br.getAttributeValue('internalId', null);
        if (id == null) {
            System.debug('❌ baseRef sin internalId');
            return null;
        }
        System.debug('✅ internalId='+id);
        return id;
    }
}