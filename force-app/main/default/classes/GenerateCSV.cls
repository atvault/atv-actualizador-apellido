public class GenerateCSV implements Database.Batchable<SObject>, Database.Stateful {

    public Integer chunkSize = 200; 
    public Integer fileCount = 1;

    public String header = 'Id,Name,Estado__c,Phone,TEL_FONO_ALTERNATIVO__c,Email__c,ATV_Email_Alternativo__c,'
                         + 'Nombre_Legal__c,BillingCountry,BillingState,BillingCity,BillingStreet,BillingPostalCode,'
                         + 'CUIT__c,Cat__c,AccountSource,Website,Tipo_de_Contribuyente__c,ATV_Rango_de_Facturaci_n__c,'
                         + 'NumberOfEmployees,Rubro__c\n';

    private Set<Id> validAccIds;
    private Set<Id> processedAccIds = new Set<Id>(); // se mantendrá entre chunks gracias a Database.Stateful

    public GenerateCSV() {
        // Obtener todas las cuentas válidas base
        List<Account> accList = [
            SELECT Id
            FROM Account 
            WHERE ID_NetSuite__c = NULL 
              AND Estado__c != '21' 
              AND Id NOT IN (SELECT AccountId FROM Opportunity)
        ];
        validAccIds = new Set<Id>();
        for (Account a : accList) {
            validAccIds.add(a.Id);
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Recuperamos todas las cuentas válidas
        return Database.getQueryLocator([SELECT Id FROM Account WHERE Id IN :validAccIds]);
    }

    public void execute(Database.BatchableContext bc, List<Account> chunkAccounts) {
        // IDs del chunk
        Set<Id> chunkAccIds = new Set<Id>();
        for(Account a : chunkAccounts){
            chunkAccIds.add(a.Id);
        }

        // IDs de cuentas con Tasks en este chunk
        Set<Id> accIdsWithTasks = new Set<Id>();
        for(Task t : [SELECT WhatId FROM Task WHERE WhatId IN :chunkAccIds]){
            if(t.WhatId != null) accIdsWithTasks.add(t.WhatId);
        }

        // Traer cuentas válidas del chunk sin Tasks y que no hayan sido procesadas aún
        List<Account> accListNoTasks = [
            SELECT Id, Name, Estado__c, Phone, TEL_FONO_ALTERNATIVO__c, Email__c, 
                   ATV_Email_Alternativo__c, Nombre_Legal__c, BillingCountry, BillingState, 
                   BillingCity, BillingStreet, BillingPostalCode, CUIT__c, Cat__c, 
                   AccountSource, Website, Tipo_de_Contribuyente__c,
                   ATV_Rango_de_Facturaci_n__c, NumberOfEmployees, Rubro__c
            FROM Account
            WHERE Id IN :chunkAccIds
              AND Id NOT IN :accIdsWithTasks
              AND Id NOT IN :processedAccIds
              AND ID_NetSuite__c = NULL
              AND Estado__c != '21'
              AND Id NOT IN (SELECT AccountId FROM Opportunity)
        ];

        Integer rowCount = 0;
        String body = header;

        for(Account acc : accListNoTasks){
            body += '"' + acc.Id + '","'
                        + acc.Name + '","'
                        + acc.Estado__c + '","'
                        + acc.Phone + '","'
                        + acc.TEL_FONO_ALTERNATIVO__c + '","'
                        + acc.Email__c + '","'
                        + acc.ATV_Email_Alternativo__c + '","'
                        + acc.Nombre_Legal__c + '","'
                        + acc.BillingCountry + '","'
                        + acc.BillingState + '","'
                        + acc.BillingCity + '","'
                        + acc.BillingStreet + '","'
                        + acc.BillingPostalCode + '","'
                        + acc.CUIT__c + '","'
                        + acc.Cat__c + '","'
                        + acc.AccountSource + '","'
                        + acc.Website + '","'
                        + acc.Tipo_de_Contribuyente__c + '","'
                        + acc.ATV_Rango_de_Facturaci_n__c + '","'
                        + acc.NumberOfEmployees + '","'
                        + acc.Rubro__c + '"\n';

            rowCount++;
            processedAccIds.add(acc.Id); // se conserva entre executes

            if (Math.mod(rowCount, chunkSize) == 0) {
                ContentVersion cv = new ContentVersion();
                cv.Title = 'AccountNoTask_Part' + fileCount;
                cv.PathOnClient = 'AccountNoTask.csv';
                cv.VersionData = Blob.valueOf(body);
                insert cv;

                body = header;
                fileCount++;
            }
        }

        // Último archivo del execute
        if (body != header) {
            ContentVersion cv = new ContentVersion();
            cv.Title = 'AccountNoTask_Part' + fileCount;
            cv.PathOnClient = 'AccountNoTask.csv';
            cv.VersionData = Blob.valueOf(body);
            insert cv;
            fileCount++;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch finalizado. Archivos generados: ' + (fileCount-1));
        System.debug('Total de cuentas procesadas únicas: ' + processedAccIds.size());
    }
}