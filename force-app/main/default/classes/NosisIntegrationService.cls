public class NosisIntegrationService {
    private Account account;

    public NosisIntegrationService(ApexPages.StandardController stdController) {
        // Asegúrate de cargar todos los campos necesarios mediante una consulta SOQL.
        this.account = [
            SELECT Id, Name, CUIT__c, Score__c, Phone, BillingStreet, BillingCity, 
                   BillingState, BillingPostalCode, BillingCountry, NumberOfEmployees
            FROM Account
            WHERE Id = :stdController.getId()
        ];

        if (this.account == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Account record is not available.'));
        }
    }

    public void getNosisScore() {
        if (this.account == null || this.account.CUIT__c == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Missing CUIT information for the Account.'));
            return;
        }

        List<API_Nosis_variables__mdt> settings = [
            SELECT Usuario_API__c, Token_API__c
            FROM API_Nosis_variables__mdt
        ];
        
        if (settings.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'API credentials are not set in Custom Metadata.'));
            return;
        }

        String usuario = EncodingUtil.urlEncode(settings[0].Usuario_API__c, 'UTF-8');
        String token = EncodingUtil.urlEncode(settings[0].Token_API__c, 'UTF-8');

        String endpoint = 'https://ws01.nosis.com/api/variables?usuario=' + usuario +
                          '&token=' + token +
                          '&documento=' + String.valueOf(this.account.CUIT__c)  +
                          '&VR=1';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');

        Http http = new Http();
        try {
            HTTPResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                processResponse(responseBody);
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Failed to retrieve data from Nosis API. HTTP Status: ' + res.getStatusCode()));
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Exception during Nosis API call: ' + e.getMessage()));
        }
    }
    private void processResponse(String responseBody) {
        try {
            String areaCode = '';
            String phoneNumber = '';
            Dom.Document doc = new Dom.Document();
            doc.load(responseBody);
            String ns = 'http://schemas.nosis.com/sac/ws01/types';
            Dom.XMLNode variablesNode = doc.getRootElement().getChildElement('Contenido', ns).getChildElement('Datos', ns).getChildElement('Variables', ns);
            if (variablesNode != null) {
                for (Dom.XMLNode variable : variablesNode.getChildElements()) {
                    String nombre = variable.getChildElement('Nombre', ns).getText();
                    String valor = variable.getChildElement('Valor', ns).getText();

                    if ('SCO_Vig'.equals(nombre)) {
                        this.account.Score__c = !String.isBlank(valor) ? Decimal.valueOf(valor) : null;
                    } else if ('VI_Empleados_Cant'.equals(nombre)) {
                        this.account.NumberOfEmployees = safeParseInt(valor);
                    } else if ('VI_DomAF_Calle'.equals(nombre)) {
                        this.account.BillingStreet = valor;
                    } else if ('VI_RazonSocial'.equals(nombre)) {
                        this.account.Name = !String.isBlank(valor) ? valor : null;
                    } else if ('VI_DomAF_Nro'.equals(nombre) && !String.isBlank(valor)) {
                        this.account.BillingStreet += ', ' + valor;
                    } else if ('VI_DomAF_Piso'.equals(nombre) && !String.isBlank(valor)) {
                        this.account.BillingStreet += ', ' + valor;
                    } else if ('VI_DomAF_Dto'.equals(nombre) && !String.isBlank(valor)) {
                        this.account.BillingStreet += ', Dto. ' + valor;
                    } else if ('VI_DomAF_Loc'.equals(nombre) && !String.isBlank(valor)) {
                        this.account.BillingCity = valor;
                    } else if ('VI_DomAF_CP'.equals(nombre) && !String.isBlank(valor)) {
                        this.account.BillingPostalCode = valor;
                    } else if ('VI_DomAF_Prov'.equals(nombre) && !String.isBlank(valor)) {
                        this.account.BillingState = valor;
                    } else if ('VI_Tel1_CodArea'.equals(nombre) && !String.isBlank(valor)) {
                        areaCode = valor;
                    } else if ('VI_Tel1_Nro'.equals(nombre) && !String.isBlank(valor)) {
                        phoneNumber = valor;
                    }
                    this.account.Phone = '(' + areaCode + ') ' + phoneNumber;
                }

                if (!String.isBlank(this.account.BillingStreet) || !String.isBlank(this.account.BillingCity) || !String.isBlank(this.account.BillingState) || !String.isBlank(this.account.BillingPostalCode)) {
                    this.account.BillingCountry = 'Argentina';
                }

                update this.account;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Account updated successfully.'));
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to locate the Variables node in the XML.'));
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error processing Nosis API response: ' + e.getMessage()));
        }
    }

    private Integer safeParseInt(String value) {
        try {
            return Integer.valueOf(value);
        } catch (Exception e) {
            return null; // Handle non-integer values safely
        }
    }
}