public class NosisIntegrationServiceForLead {
    private Lead lead;

    public NosisIntegrationServiceForLead(ApexPages.StandardController stdController) {
        this.lead = [
            SELECT Id, Company, CUIT__c, Score_Nosis__c, NumberOfEmployees, Phone, Street, City, State, PostalCode, Country
            FROM Lead
            WHERE Id = :stdController.getId()
        ];

        if (this.lead == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Lead record is not available.'));
        }
    }

    public void getNosisScore() {
        if (this.lead == null || this.lead.CUIT__c == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Missing Lead or CUIT information.'));
            return;
        }

        // Recuperar las credenciales API desde Custom Metadata Types
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
                          '&documento=' + this.lead.CUIT__c +
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
        Dom.Document doc = new Dom.Document();
        doc.load(responseBody);
        String ns = 'http://schemas.nosis.com/sac/ws01/types';
        Dom.XMLNode contentNode = doc.getRootElement().getChildElement('Contenido', ns);
        if (contentNode == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'vertencia.'));

            return;
        }

        Dom.XMLNode datosNode = contentNode.getChildElement('Datos', ns);
        if (datosNode == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'No data found.'));
            return;
        }

        Dom.XMLNode variablesNode = datosNode.getChildElement('Variables', ns);
if (variablesNode == null || variablesNode.getChildElements().size() == 0 || variablesNode.getChildElements().isEmpty()) {
    // Agrega un mensaje de advertencia cuando no hay variables en el nodo de datos.
    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No variables found in the data.'));
    return;
}

        // Processing each variable found
        for (Dom.XMLNode variable : variablesNode.getChildElements()) {
            Dom.XMLNode nombreNode = variable.getChildElement('Nombre', ns);
            Dom.XMLNode valorNode = variable.getChildElement('Valor', ns);
            if (nombreNode == null || valorNode == null) {
                // Agrega un mensaje de advertencia si falta el nombre o el valor de la variable.
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Variable name or value is missing.'));
                continue;
            }
            String nombre = nombreNode.getText();
            String valor = valorNode.getText();

            // Actualiza los campos del lead basado en el nombre y valor de la variable.
            updateLeadField(nombre, valor);
        }

        // Aplica las actualizaciones al lead en la base de datos.
        if (this.lead != null && this.lead.Id != null) {
            update this.lead; 
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Lead updated successfully.'));
        }
    } catch (Exception e) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error processing Nosis API response: ' + e.getMessage()));
    }
}


private void updateLeadField(String fieldName, String fieldValue) {
    switch on fieldName {
        when 'SCO_Vig' {
            this.lead.Score_Nosis__c = Decimal.valueOf(fieldValue);
        }
        when 'VI_Empleados_Cant' {
            this.lead.NumberOfEmployees = Integer.valueOf(fieldValue);
        }
        when 'VI_RazonSocial' {
            this.lead.Company = fieldValue;
        }
        when 'VI_DomAF_CP' {
            this.lead.PostalCode = fieldValue;
        }
        when 'VI_DomAF_Prov' {
            this.lead.State = fieldValue;
        }
        when 'VI_DomAF_Calle', 'VI_DomAF_Nro', 'VI_DomAF_Piso', 'VI_DomAF_Dto', 'VI_DomAF_Loc' {
            concatenateAddressComponents(fieldName, fieldValue);
        }
        when 'VI_Tel1_CodArea', 'VI_Tel1_Nro' {
            updatePhoneNumber(fieldName, fieldValue);
        }
    }
     if (!String.isBlank(this.lead.Street) || !String.isBlank(this.lead.City) || !String.isBlank(this.lead.State) || !String.isBlank(this.lead.PostalCode)) {
                    this.lead.Country = 'Argentina';
                }
}

private void concatenateAddressComponents(String field, String value) {
    // Sobrescribir la calle si es 'VI_DomAF_Calle'
    if (field.equals('VI_DomAF_Calle')) {
        this.lead.Street = value;
    } 
    // Concatenar el número a la calle si es 'VI_DomAF_Nro'
    else if (field.equals('VI_DomAF_Nro')) {
        if (this.lead.Street != null) {
            this.lead.Street += ', ' + value;
        } else {
            this.lead.Street = value;
        }
    } 
    // Añadir información de piso si es 'VI_DomAF_Piso'
    else if (field.equals('VI_DomAF_Piso')) {
        if (this.lead.Street != null) {
            this.lead.Street += ', Piso ' + value;
        } else {
            this.lead.Street = 'Piso ' + value;
        }
    } 
    // Añadir información de departamento si es 'VI_DomAF_Dto'
    else if (field.equals('VI_DomAF_Dto')) {
        if (this.lead.Street != null) {
            this.lead.Street += ', Dto. ' + value;
        } else {
            this.lead.Street = 'Dto. ' + value;
        }
    } 
    // Añadir localidad si es 'VI_DomAF_Loc'
    else if (field.equals('VI_DomAF_Loc')) {
        if (this.lead.Street != null) {
            this.lead.Street += ', ' + value;
            this.lead.City = value;  // Asigna también a la ciudad
        } else {
            this.lead.Street = value;
            this.lead.City = value;
        }
    }
}



private void updatePhoneNumber(String field, String value) {
    if (field == 'VI_Tel1_CodArea') {
        this.lead.Phone = '(' + value + ')';
    } else if (field == 'VI_Tel1_Nro' && this.lead.Phone != null) {
        this.lead.Phone += ' ' + value;
    }
}
}