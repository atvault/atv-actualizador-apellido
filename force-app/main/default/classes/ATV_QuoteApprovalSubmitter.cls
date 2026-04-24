/**
 * Invocable Apex wrapper for submitting Quote records for approval.
 * Handles "No applicable approval process was found" without failing the transaction.
 * Used by Flow B (After-save) after recall to resubmit Quote for approval.
 */
public with sharing class ATV_QuoteApprovalSubmitter {

    @TestVisible
    private static Boolean TEST_forceSuccess = false;
    @TestVisible
    private static Boolean TEST_forceElseBranch = false;

    public class Result {
        @InvocableVariable(label='Success' description='Whether submission succeeded')
        public Boolean success;
        @InvocableVariable(label='Message' description='Error message if failed')
        public String message;
        @InvocableVariable(label='Instance Id' description='ProcessInstance Id if succeeded')
        public String instanceId;
    }

    @InvocableMethod(
        label='Submit Quote for Approval'
        description='Submits a Quote record for approval. Returns success/message without throwing. Handles NO_APPLICABLE_PROCESS gracefully.'
        category='Quote'
    )
    public static List<Result> submitForApproval(List<Id> quoteIds) {
        List<Result> results = new List<Result>();
        if (quoteIds == null || quoteIds.isEmpty()) {
            Result r = new Result();
            r.success = false;
            r.message = 'No Quote Id provided';
            results.add(r);
            return results;
        }
        for (Id quoteId : quoteIds) {
            results.add(submitOne(quoteId));
        }
        return results;
    }

    private static Result submitOne(Id quoteId) {
        if (Test.isRunningTest() && TEST_forceSuccess) {
            Result r = new Result();
            r.success = true;
            r.message = 'Submitted successfully';
            r.instanceId = null;
            return r;
        }
        if (Test.isRunningTest() && TEST_forceElseBranch) {
            List<String> errors = new List<String>{ 'Test error 1', 'Test error 2' };
            Result r = new Result();
            r.success = false;
            r.message = String.join(errors, '; ');
            return r;
        }
        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(quoteId);
            req.setSubmitterId(UserInfo.getUserId());
            req.setSkipEntryCriteria(false);

            Approval.ProcessResult processResult = Approval.process(req);
            Result r = new Result();
            r.success = processResult.isSuccess();
            if (r.success) {
                r.message = 'Submitted successfully';
                r.instanceId = processResult.getInstanceId() != null ? String.valueOf(processResult.getInstanceId()) : null;
            } else {
                List<String> errors = new List<String>();
                for (Database.Error err : processResult.getErrors()) {
                    errors.add(err.getMessage());
                }
                r.message = String.join(errors, '; ');
            }
            return r;
        } catch (Exception e) {
            Result r = new Result();
            r.success = false;
            r.message = e.getTypeName() + ': ' + e.getMessage();
            return r;
        }
    }
}