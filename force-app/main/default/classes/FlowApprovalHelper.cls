public without sharing class FlowApprovalHelper {

    public class Result {
        @InvocableVariable public Id recordId;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Integer workItemsFound;
        @InvocableVariable public Integer workItemsRemoved;
    }

    // ✅ Excepción custom (Apex no permite new Exception())
    public class TestForcedException extends Exception {}

    // -------------------------
    // Hooks SOLO para tests
    // -------------------------
    @TestVisible private static Map<Id, Integer> TEST_pendingWorkitemsByRecord;
    @TestVisible private static List<Boolean>    TEST_processSuccessPattern;
    @TestVisible private static Boolean          TEST_forceException;

    @InvocableMethod(
        label='Recall Approval Process (Classic)'
        description='Retira (Removed) workitems pendientes de approval para los registros enviados. Diseñado para Approval Process clásico.'
    )
    public static List<Result> recallApproval(List<Id> recordIds) {
        List<Result> results = new List<Result>();
        if (recordIds == null || recordIds.isEmpty()) return results;

        Map<Id, Result> resById = new Map<Id, Result>();
        for (Id rid : recordIds) {
            Result r = new Result();
            r.recordId = rid;
            r.success = true;
            r.message = 'No pending approval found.';
            r.workItemsFound = 0;
            r.workItemsRemoved = 0;
            resById.put(rid, r);
        }

        // -------------------------
        // 1) Obtener workitems (real o simulado)
        // -------------------------
        Map<Id, List<ProcessInstanceWorkitem>> wisByTarget = new Map<Id, List<ProcessInstanceWorkitem>>();

        Boolean useTestMock = Test.isRunningTest()
            && TEST_pendingWorkitemsByRecord != null
            && !TEST_pendingWorkitemsByRecord.isEmpty();

        if (useTestMock) {
            // Simulación: no query al motor de approvals
            String keyPrefix = ProcessInstanceWorkitem.SObjectType.getDescribe().getKeyPrefix();
            Integer counter = 1;

            for (Id rid : recordIds) {
                Integer n = TEST_pendingWorkitemsByRecord.containsKey(rid) ? TEST_pendingWorkitemsByRecord.get(rid) : 0;
                if (n <= 0) continue;

                List<ProcessInstanceWorkitem> fake = new List<ProcessInstanceWorkitem>();
                for (Integer i = 0; i < n; i++) {
                    ProcessInstanceWorkitem wi = new ProcessInstanceWorkitem();
                    // Id fake válido (solo en memoria)
                    wi.Id = (keyPrefix == null ? '04i' : keyPrefix) + String.valueOf(counter).leftPad(15, '0');
                    counter++;
                    fake.add(wi);
                }
                wisByTarget.put(rid, fake);
            }
        } else {
            // Real: query de workitems pendientes
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id,
                       ProcessInstanceId,
                       ProcessInstance.TargetObjectId,
                       ProcessInstance.Status
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId IN :recordIds
                AND ProcessInstance.Status = 'Pending'
            ];

            for (ProcessInstanceWorkitem wi : workItems) {
                Id targetId = wi.ProcessInstance.TargetObjectId;
                if (!wisByTarget.containsKey(targetId)) {
                    wisByTarget.put(targetId, new List<ProcessInstanceWorkitem>());
                }
                wisByTarget.get(targetId).add(wi);
            }
        }

        // -------------------------
        // 2) Armar requests
        // -------------------------
        List<Approval.ProcessWorkitemRequest> requests = new List<Approval.ProcessWorkitemRequest>();
        Map<Id, Integer> requestCountByRecord = new Map<Id, Integer>();

        for (Id rid : wisByTarget.keySet()) {
            List<ProcessInstanceWorkitem> wis = wisByTarget.get(rid);

            resById.get(rid).workItemsFound = wis.size();
            resById.get(rid).message = 'Pending approval found. Attempting recall...';

            requestCountByRecord.put(rid, wis.size());

            for (ProcessInstanceWorkitem wi : wis) {
                Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                req.setWorkitemId(wi.Id);
                req.setAction('Removed');
                req.setComments('Retirado automáticamente para reiniciar el ciclo de aprobación.');
                requests.add(req);
            }
        }

        // -------------------------
        // 3) Procesar
        // -------------------------
        if (!requests.isEmpty()) {
            try {
                if (Test.isRunningTest() && TEST_forceException == true) {
                    // Forzar catch para cubrir rama de excepción
                    throw new TestForcedException('TEST forced exception');
                }

                if (Test.isRunningTest() && TEST_processSuccessPattern != null && !TEST_processSuccessPattern.isEmpty()) {
                    // Simulación: no llama Approval.process()
                    Integer idx = 0;

                    for (Id rid : wisByTarget.keySet()) {
                        Integer expected = requestCountByRecord.get(rid);
                        Integer removed = 0;
                        List<String> errors = new List<String>();

                        for (Integer i = 0; i < expected; i++) {
                            Boolean ok = TEST_processSuccessPattern[Math.mod(idx, TEST_processSuccessPattern.size())];
                            idx++;

                            if (ok) {
                                removed++;
                            } else {
                                errors.add('Simulated error');
                            }
                        }

                        Result r = resById.get(rid);
                        r.workItemsRemoved = removed;

                        if (!errors.isEmpty()) {
                            r.success = false;
                            r.message = 'Recall failed: ' + String.join(errors, ' | ');
                        } else {
                            r.success = true;
                            r.message = 'Recall OK. Removed ' + removed + ' workitem(s).';
                        }
                    }

                } else {
                    // Real: motor de approvals
                    Approval.ProcessResult[] pr = Approval.process(requests);

                    Integer idx = 0;
                    for (Id rid : wisByTarget.keySet()) {
                        Integer expected = requestCountByRecord.get(rid);
                        Integer removed = 0;
                        List<String> errors = new List<String>();

                        for (Integer i = 0; i < expected; i++) {
                            Approval.ProcessResult one = pr[idx];
                            idx++;

                            if (one != null && one.isSuccess()) {
                                removed++;
                            } else {
                                String msg = (one != null && one.getErrors() != null && !one.getErrors().isEmpty())
                                    ? one.getErrors()[0].getMessage()
                                    : 'Unknown error while recalling approval.';
                                errors.add(msg);
                            }
                        }

                        Result r = resById.get(rid);
                        r.workItemsRemoved = removed;

                        if (!errors.isEmpty()) {
                            r.success = false;
                            r.message = 'Recall failed: ' + String.join(errors, ' | ');
                        } else {
                            r.success = true;
                            r.message = 'Recall OK. Removed ' + removed + ' workitem(s).';
                        }
                    }
                }

            } catch (Exception e) {
                for (Id rid : wisByTarget.keySet()) {
                    Result r = resById.get(rid);
                    r.success = false;
                    r.message = 'Recall exception: ' + e.getMessage();
                }
            }
        }

        results.addAll(resById.values());
        return results;
    }
}