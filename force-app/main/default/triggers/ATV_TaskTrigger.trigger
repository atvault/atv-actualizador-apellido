/**
* @description: Task trigger with ATV_ prefix for AT Vault implementations
* @author: AT Vault
*/
trigger ATV_TaskTrigger on Task (after insert, after update, after delete, after undelete) {
    if(Castle_Flags.updateContactCUIT == false){
        Set<Id> accountIds = new Set<Id>();
        
        if(Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
            for(Task t : Trigger.new) {
                // Only count tasks that are calls, associated with accounts, and whose subject starts with "R -"
                if(t.WhatId != null && 
                   String.valueOf(t.WhatId).startsWith('001') && 
                   t.TaskSubtype == 'Call' && 
                   t.Subject != null && 
                   t.Subject.startsWith('R -')) {
                       accountIds.add(t.WhatId);
                   }
            }
        }
        
        if(Trigger.isDelete) {
            for(Task t : Trigger.old) {
                // Only count tasks that are calls, associated with accounts, and whose subject starts with "R -"
                if(t.WhatId != null && 
                   String.valueOf(t.WhatId).startsWith('001') && 
                   t.TaskSubtype == 'Call' && 
                   t.Subject != null && 
                   t.Subject.startsWith('R -')) {
                       accountIds.add(t.WhatId);
                   }
            }
        }
        
        if(!accountIds.isEmpty()){
            ATV_AccountHelper.updateAccountCallCounts(accountIds);
        }
    }
}