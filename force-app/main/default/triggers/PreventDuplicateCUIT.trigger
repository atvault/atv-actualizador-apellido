trigger PreventDuplicateCUIT on Lead (before insert) {
    // Conjunto para almacenar los CUIT (Decimal) de los nuevos Leads
    Set<Decimal> cuitSet = new Set<Decimal>();
    
    // Recopilar los CUIT ingresados en los nuevos Leads
    for (Lead l : Trigger.new) {
        l.LastName = l.Company;
        if (l.CUIT__c != null) {
            cuitSet.add(l.CUIT__c);
        }
    }

    // Consultar las Accounts que ya tienen alguno de estos CUIT
    Map<Decimal, Account> existingAccounts = new Map<Decimal, Account>();
    if (!cuitSet.isEmpty()) {
        for (Account acc : [SELECT CUIT__c FROM Account WHERE CUIT__c IN :cuitSet]) {
            existingAccounts.put(acc.CUIT__c, acc);
        }
    }

    // Validar si ya existe una Account con el mismo CUIT y bloquear la creación del Lead
    for (Lead l : Trigger.new) {
        if (l.CUIT__c != null && existingAccounts.containsKey(l.CUIT__c)) {
            l.addError('Ya existe una cuenta con este CUIT. No se puede crear el Lead.');
        }
    }
}