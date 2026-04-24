trigger TRG_Contact on Contact (after insert, after update) {
    if(!Castle_Flags.updateContactCUIT){
        if(Trigger.isInsert) {
            HND_Contact.sendContactToNetSuite(Trigger.new, null);
        }
        if(Trigger.isUpdate) {
            HND_Contact.sendContactToNetSuite(Trigger.new, Trigger.oldMap);
        } 
    }
}