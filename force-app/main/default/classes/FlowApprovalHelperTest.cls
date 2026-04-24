@IsTest
private class FlowApprovalHelperTest {

    private static User makeUser(String unique) {
        User running = [
            SELECT ProfileId, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, LanguageLocaleKey
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        User u = new User(
            ProfileId = running.ProfileId,
            Username = 'flow.approval.' + unique + '.' + System.now().getTime() + '@example.com',
            Email = 'flow.approval.' + unique + '@example.com',
            LastName = 'Tester ' + unique,
            Alias = ('t' + unique).left(8),
            TimeZoneSidKey = running.TimeZoneSidKey,
            LocaleSidKey = running.LocaleSidKey,
            EmailEncodingKey = running.EmailEncodingKey,
            LanguageLocaleKey = running.LanguageLocaleKey
        );
        insert u;
        return u;
    }

    private static Opportunity makeOpportunity(Id ownerId) {
        Account a = new Account(Name = 'Acct Test ' + String.valueOf(System.now().getTime()));
        insert a;

        // StageName válido + priorizar MQL si existe (para evitar VR "Falta Contacto principal")
        List<Schema.PicklistEntry> stages = Opportunity.StageName.getDescribe().getPicklistValues();
        String chosenStage = null;

        for (Schema.PicklistEntry pe : stages) {
            if (pe.isActive() && pe.getValue() == 'MQL') {
                chosenStage = 'MQL';
                break;
            }
        }
        if (chosenStage == null) {
            for (Schema.PicklistEntry pe : stages) {
                if (pe.isActive()) {
                    chosenStage = pe.getValue();
                    break;
                }
            }
        }

        Opportunity o = new Opportunity(
            Name      = 'Opp Test ' + String.valueOf(System.now().getTime()),
            AccountId = a.Id,
            StageName = chosenStage,
            CloseDate = Date.today().addDays(10),
            OwnerId   = ownerId
        );

        // Robustez: si existe el checkbox, lo seteamos
        Map<String, Schema.SObjectField> f = Opportunity.SObjectType.getDescribe().fields.getMap();
        if (f.containsKey('Primary_Contact__c')) {
            o.put('Primary_Contact__c', true);
        }

        insert o;
        return o;
    }

    private static void resetHelperHooks() {
        FlowApprovalHelper.TEST_pendingWorkitemsByRecord = null;
        FlowApprovalHelper.TEST_processSuccessPattern = null;
        FlowApprovalHelper.TEST_forceException = null;
    }

    @IsTest
    static void test_recallApproval_noInput() {
        resetHelperHooks();

        Test.startTest();
        System.assertEquals(0, FlowApprovalHelper.recallApproval(null).size());
        System.assertEquals(0, FlowApprovalHelper.recallApproval(new List<Id>()).size());
        Test.stopTest();
    }

    @IsTest
    static void test_recallApproval_noPendingApproval() {
        resetHelperHooks();

        User u = makeUser('nopending');
        Opportunity o = makeOpportunity(u.Id);

        Test.startTest();
        List<FlowApprovalHelper.Result> res = FlowApprovalHelper.recallApproval(new List<Id>{ o.Id });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(o.Id, res[0].recordId);
        System.assertEquals(true, res[0].success);
        System.assertEquals(0, res[0].workItemsFound);
        System.assertEquals(0, res[0].workItemsRemoved);
        System.assertNotEquals(null, res[0].message);
    }

    @IsTest
    static void test_mock_bulk_all_success() {
        resetHelperHooks();

        User u = makeUser('ok');
        Opportunity o1 = makeOpportunity(u.Id);
        Opportunity o2 = makeOpportunity(u.Id);

        FlowApprovalHelper.TEST_pendingWorkitemsByRecord = new Map<Id, Integer>{
            o1.Id => 2,
            o2.Id => 1
        };
        FlowApprovalHelper.TEST_processSuccessPattern = new List<Boolean>{ true };
        FlowApprovalHelper.TEST_forceException = false;

        Test.startTest();
        List<FlowApprovalHelper.Result> res =
            FlowApprovalHelper.recallApproval(new List<Id>{ o1.Id, o2.Id });
        Test.stopTest();

        System.assertEquals(2, res.size());
        for (FlowApprovalHelper.Result r : res) {
            System.assertEquals(true, r.success);
            System.assert(r.workItemsFound > 0);
            System.assertEquals(r.workItemsFound, r.workItemsRemoved);
            System.assert(r.message != null && r.message.contains('Recall OK'));
        }
    }

    @IsTest
    static void test_mock_bulk_partial_fail() {
        resetHelperHooks();

        User u = makeUser('partial');
        Opportunity o1 = makeOpportunity(u.Id);

        FlowApprovalHelper.TEST_pendingWorkitemsByRecord = new Map<Id, Integer>{
            o1.Id => 3
        };
        FlowApprovalHelper.TEST_processSuccessPattern = new List<Boolean>{ true, false };
        FlowApprovalHelper.TEST_forceException = false;

        Test.startTest();
        List<FlowApprovalHelper.Result> res =
            FlowApprovalHelper.recallApproval(new List<Id>{ o1.Id });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(false, res[0].success);
        System.assertEquals(3, res[0].workItemsFound);
        System.assert(res[0].workItemsRemoved < res[0].workItemsFound);
        System.assert(res[0].message != null && res[0].message.startsWith('Recall failed:'));
    }

    @IsTest
    static void test_mock_bulk_exception_path() {
        resetHelperHooks();

        User u = makeUser('ex');
        Opportunity o1 = makeOpportunity(u.Id);

        FlowApprovalHelper.TEST_pendingWorkitemsByRecord = new Map<Id, Integer>{
            o1.Id => 1
        };
        FlowApprovalHelper.TEST_processSuccessPattern = new List<Boolean>{ true };
        FlowApprovalHelper.TEST_forceException = true;

        Test.startTest();
        List<FlowApprovalHelper.Result> res =
            FlowApprovalHelper.recallApproval(new List<Id>{ o1.Id });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message != null && res[0].message.startsWith('Recall exception:'));
    }

    /**
     * ✅ NUEVO: fuerza el branch REAL (Approval.process(requests)) para cubrir líneas rojas.
     * - Crea requests con TEST_pendingWorkitemsByRecord
     * - NO setea TEST_processSuccessPattern (null) para que no entre al branch simulado
     */
    @IsTest
    static void test_force_real_approval_branch_coverage() {
        resetHelperHooks();

        User u = makeUser('realbranch');
        Opportunity o1 = makeOpportunity(u.Id);

        // Genera requests (mock de workitems)
        FlowApprovalHelper.TEST_pendingWorkitemsByRecord = new Map<Id, Integer>{
            o1.Id => 2
        };

        // IMPORTANTÍSIMO: null => entra al branch REAL (Approval.process)
        FlowApprovalHelper.TEST_processSuccessPattern = null;
        FlowApprovalHelper.TEST_forceException = false;

        Test.startTest();
        List<FlowApprovalHelper.Result> res =
            FlowApprovalHelper.recallApproval(new List<Id>{ o1.Id });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(o1.Id, res[0].recordId);

        // Puede terminar en "failed" o en "exception" dependiendo del comportamiento de Approval.process
        System.assertEquals(false, res[0].success, 'Expected failure/exception for real-branch coverage with fake workitem Ids');
        System.assert(res[0].message != null);
        System.assert(
            res[0].message.startsWith('Recall failed:') || res[0].message.startsWith('Recall exception:'),
            'Expected Recall failed/exception message'
        );
    }
}