public with sharing class ConsumoActualController {
    public List<Consumo_Actual__c> consumos { get; set; }
    private final Account account;

    public ConsumoActualController(ApexPages.StandardController stdController) {
        this.account = (Account)stdController.getRecord();
        consumos = [SELECT Id, Producto__c, Cantidad__c, Precio__c, Total__c, Frecuencia__c FROM Consumo_Actual__c WHERE Cuenta__c = :account.Id];
    }
    
    public void addNewConsumoActual() {
        Consumo_Actual__c newConsumo = new Consumo_Actual__c(Cuenta__c = account.Id);
        consumos.add(newConsumo);
    }
    
    public PageReference save() {
        try {
            upsert consumos;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
        return new PageReference('/' + account.Id); // redirect to Account page
    }
}