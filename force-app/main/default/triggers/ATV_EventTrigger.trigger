/**
 * @description: Event trigger with ATV_ prefix for AT Vault implementations
 * @author: AT Vault
 */
trigger ATV_EventTrigger on Event (after insert, after update, after delete, after undelete) {
    Set<Id> accountIds = new Set<Id>();
    
    if(Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for(Event e : Trigger.new) {
            if(e.WhatId != null && String.valueOf(e.WhatId).startsWith('001')) {
                accountIds.add(e.WhatId);
            }
        }
    }
    
    if(Trigger.isDelete) {
        for(Event e : Trigger.old) {
            if(e.WhatId != null && String.valueOf(e.WhatId).startsWith('001')) {
                accountIds.add(e.WhatId);
            }
        }
    }
    
    if(!accountIds.isEmpty()){
        ATV_AccountHelper.updateAccountMeetingCounts(accountIds);
    }
}