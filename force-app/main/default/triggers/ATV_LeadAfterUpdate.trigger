trigger ATV_LeadAfterUpdate on Lead (after update) {
    ATV_LeadConvertToDireccionService.createFromConvertedLeads(Trigger.new, Trigger.oldMap);
}