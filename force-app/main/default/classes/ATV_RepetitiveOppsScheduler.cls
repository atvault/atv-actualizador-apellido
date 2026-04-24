global with sharing class ATV_RepetitiveOppsScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
		Date runDate = Date.today();
		Database.executeBatch(new ATV_RepetitiveOppsBatch(runDate), 200);
	}

	public static void scheduleMonthly() {
		// Verificar si ya existe un job programado
		List<CronTrigger> existingJobs = [
			SELECT Id FROM CronTrigger 
			WHERE CronJobDetail.Name = 'ATV_RepetitiveOpps Monthly'
		];
		if (!existingJobs.isEmpty()) {
			return; // Ya existe, no hacer nada
		}
		String cron = '0 10 0 1 * ?';
		System.schedule('ATV_RepetitiveOpps Monthly', cron, new ATV_RepetitiveOppsScheduler());
	}
}