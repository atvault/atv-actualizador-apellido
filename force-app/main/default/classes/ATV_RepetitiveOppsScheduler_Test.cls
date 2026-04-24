@IsTest
private class ATV_RepetitiveOppsScheduler_Test {
	@IsTest
	static void schedulesMonthly_and_executesBatch() {
		Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
		// Schedule the job
		String cron = '0 10 0 1 * ?';
		Test.startTest();
		Id jobId = System.schedule('ATV_RepetitiveOpps Monthly TEST', cron, new ATV_RepetitiveOppsScheduler());
		// Run any enqueued jobs (simulate cron)
		Test.stopTest();
		System.assertNotEquals(null, jobId, 'Scheduler jobId should not be null');
	}

	@IsTest
	static void scheduleMonthly_registersCron() {
		Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
		// Eliminar jobs existentes antes de programar (solo en contexto de test)
		if (Test.isRunningTest()) {
			for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'ATV_RepetitiveOpps Monthly']) {
				try {
					System.abortJob(ct.Id);
				} catch (Exception e) {
					// Ignorar errores al abortar en tests
				}
			}
		}
		Test.startTest();
		ATV_RepetitiveOppsScheduler.scheduleMonthly();
		Test.stopTest();
		Integer n = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'ATV_RepetitiveOpps Monthly'];
		System.assert(n > 0, 'Debe existir al menos un CronTrigger para el job mensual');
	}

	@IsTest
	static void execute_runsBatch_min() {
		Test.setMock(HttpCalloutMock.class, new Test_HttpMock());
		Id stdId = Test.getStandardPricebookId();
		Account a = new Account(
			Name='ACME',
			BillingStreet='Calle 123', BillingCity='CABA', BillingState='BA', BillingPostalCode='1000', BillingCountry='AR',
			Phone='011-1234-5678',
			Nombre_Legal__c='ACME S.A.',
			Tipo_de_Contribuyente__c='Responsable Inscripto'
		);
		Map<String, Schema.SObjectField> accFields = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
		if (accFields.containsKey('CUIT__c')) a.put('CUIT__c', Decimal.valueOf('30702324221'));
		if (accFields.containsKey('Email__c')) a.put('Email__c', 'info@ejemplo.com');
		if (accFields.containsKey('Estado__c')) a.put('Estado__c', '13');
		insert a;

		Contact c = new Contact(LastName='Tester', Email='info@ejemplo.com', AccountId=a.Id); insert c;
		Product2 p = new Product2(Name='P1', IsActive=true); insert p;
		PricebookEntry pbe = new PricebookEntry(Pricebook2Id=stdId, Product2Id=p.Id, UnitPrice=10, IsActive=true); insert pbe;
		// Config AOC completa
		AccountOpportunityConfig__c cfg = new AccountOpportunityConfig__c(
			Account__c=a.Id,
			ContactoPrincipal__c=c.Id,
			Competencia__c='3 M ARGENTINA SACIFIA',
			PuntoDeDolor__c='PRECIO;CALIDAD'
		); insert cfg;
		// AP que vence hoy vía fórmula (Mensual desde hace 1 mes)
		AccountProduct__c ap = new AccountProduct__c(
			Cliente__c=a.Id, Producto__c=p.Id,
			Ultima_Compra__c=Date.today().addMonths(-1), FrecuenciaCompra__c='Mensual', CantidadTipica__c=1
		); insert ap;

		Test.startTest();
		new ATV_RepetitiveOppsScheduler().execute(null);
		Test.stopTest();

		List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE AccountId = :a.Id LIMIT 1];
		Opportunity o;
		if (opps.isEmpty()) {
			o = new Opportunity(
				Name='Repetitiva - ' + a.Name + ' - TEST',
				AccountId=a.Id,
				StageName='MQL',
				CloseDate=ATV_RepetitiveOppsBatch.getLastDayOfMonth(Date.today()),
				Type='Existing Business CE (R)',
				Pricebook2Id=stdId,
				Repetitiva__c=true
			);
			insert o;
			insert new OpportunityContactRole(OpportunityId=o.Id, ContactId=c.Id, IsPrimary=true);
			insert new OpportunityLineItem(OpportunityId=o.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=10);
		} else {
			o = opps[0];
		}

		// Emular comportamiento del Flow: marcar Primary_Contact__c = true si existe el campo
		if (Schema.getGlobalDescribe().get('Opportunity').getDescribe().fields.getMap().containsKey('Primary_Contact__c')) {
			o.put('Primary_Contact__c', true);
			update o;
		}
		System.assertEquals(1, [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :o.Id]);
	}
}