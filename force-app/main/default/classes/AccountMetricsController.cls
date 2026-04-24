public class AccountMetricsController {
    private final Account account;
    
    public AccountMetricsController(ApexPages.StandardController stdController) {
        if (!Test.isRunningTest()) {
            stdController.addFields(new List<String>{'Consumo_actual_total__c', 'Venta_Total_del_Mes__c'});
        }
        this.account = (Account)stdController.getRecord();
	}

    public Decimal getConsumoActualTotal() {
        return (account.Consumo_actual_total__c != null) ? account.Consumo_actual_total__c.setScale(0) : 0;
    }
    
    public Decimal getVentaTotalDelMes() {
        return (account.Venta_Total_del_Mes__c != null) ? account.Venta_Total_del_Mes__c.setScale(0) : 0;
    }
    
    public String getMarketShare() {
        Decimal consumoTotal = getConsumoActualTotal();
        Decimal ventaTotal = getVentaTotalDelMes();
        
        if (consumoTotal > 0) {
            Decimal marketShare = (ventaTotal / consumoTotal) * 100;
            return marketShare.setScale(0).format() + '%';
        }
        return '0%';
    }
}