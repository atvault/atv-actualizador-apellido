trigger TRG_Account on Account (after insert, after update) {
    if(!Castle_Flags.updateContactCUIT){
        if(Trigger.isInsert) {
            HND_Account.sendAccountToNetSuite(Trigger.new, null);
        }
        if(Trigger.isUpdate) {
            HND_Account.sendAccountToNetSuite(Trigger.new, Trigger.oldMap);
        }
    }
}