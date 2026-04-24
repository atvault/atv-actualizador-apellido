trigger TRG_Quote on Quote (after update) {
    if(Trigger.isUpdate) {
        HND_Quote.sendQuoteToNetSuite(Trigger.new, Trigger.oldMap);
    }
}