trigger UpdateAccountMeetingsAndCalls on Task (after insert, after update, after delete, after undelete) {
    if(Castle_Flags.updateContactCUIT == false){
        // 1. Identificamos las cuentas afectadas
        Set<Id> accountIds = new Set<Id>();
        
        if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
            for (Task t : Trigger.new) {
                // Verificamos que WhatId apunte a una Account (objeto con prefix '001')
                if (t.WhatId != null && String.valueOf(t.WhatId).startsWith('001')) {
                    accountIds.add(t.WhatId);
                }
            }
        }
        if (Trigger.isDelete) {
            for (Task t : Trigger.old) {
                if (t.WhatId != null && String.valueOf(t.WhatId).startsWith('001')) {
                    accountIds.add(t.WhatId);
                }
            }
        }
        
        if (accountIds.isEmpty()) {
            return;
        }
        
        // 2. Obtenemos la info de cada Account (fechas y campos)
        //    X1er_Opp_Atenci_n__c es un DateTime (roll-up)
        //    ATV_Fecha_de_No_Cualificado__c es Date (asumido), la convertiremos a DateTime
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, CreatedDate,
            X1er_Opp_Atenci_n__c,     // DateTime
            ATV_Fecha_de_No_Cualificado__c // Date
            FROM Account
            WHERE Id IN :accountIds
        ]);
        
        // 3. Inicializamos contadores en 0
        Map<Id, Integer> reunionesCountMap = new Map<Id, Integer>();
        Map<Id, Integer> llamadasCountMap   = new Map<Id, Integer>();
        for (Id accId : accountMap.keySet()) {
            reunionesCountMap.put(accId, 0);
            llamadasCountMap.put(accId, 0);
        }
        
        // 4. Traemos todas las Tareas de esas cuentas
        List<Task> relatedTasks = [
            SELECT Id, WhatId, Subject, CallType, CreatedDate
            FROM Task
            WHERE WhatId IN :accountMap.keySet()
        ];
        
        for (Task recordT : relatedTasks) {
            Account acc = accountMap.get(recordT.WhatId);
            if (acc == null) continue;
            
            // Convirtiendo X1er_Opp_Atenci_n__c a DateTime
            DateTime oppDateTime = acc.X1er_Opp_Atenci_n__c; // podría ser null
            
            // Convirtiendo ATV_Fecha_de_No_Cualificado__c (Date) a DateTime (medianoche)
            DateTime noCualificadoDateTime = null;
            if (acc.ATV_Fecha_de_No_Cualificado__c != null) {
                noCualificadoDateTime = DateTime.newInstance(
                    acc.ATV_Fecha_de_No_Cualificado__c,
                    Time.newInstance(0, 0, 0, 0)
                );
            }
            
            // Tomamos la fecha más temprana entre oppDateTime y noCualificadoDateTime
            DateTime fechaLimite = oppDateTime;
            if (noCualificadoDateTime != null) {
                if (fechaLimite == null || noCualificadoDateTime < fechaLimite) {
                    fechaLimite = noCualificadoDateTime;
                }
            }
            
            // Filtramos por CreatedDate dentro del rango:
            // desde acc.CreatedDate (DateTime) hasta fechaLimite (DateTime)
            Boolean enRango = (
                recordT.CreatedDate >= acc.CreatedDate &&
                (fechaLimite == null || recordT.CreatedDate <= fechaLimite)
            );
            
            if (enRango && recordT.Subject != null && recordT.Subject.startsWith('R -')) {
                // Si es llamada (CallType = 'Call')
                if (recordT.CallType == 'Call') {
                    llamadasCountMap.put(recordT.WhatId, llamadasCountMap.get(recordT.WhatId) + 1);
                }
                // De lo contrario, la contamos como reunión
                else {
                    reunionesCountMap.put(recordT.WhatId, reunionesCountMap.get(recordT.WhatId) + 1);
                }
            }
        }
        
        // 5. Actualizamos las cuentas con los valores finales
        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : accountMap.keySet()) {
            Account accToUpdate = accountMap.get(accId);
            accToUpdate.ATV_Total_Reuniones__c = reunionesCountMap.get(accId);
            accToUpdate.ATV_Total_Llamadas__c  = llamadasCountMap.get(accId);
            accountsToUpdate.add(accToUpdate);
        }
        
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
}