@isTest
private class AccountMetricsControllerTest {
    
    @isTest static void testAccountMetricsCalculations() {
        // Crear productos de prueba
        Product2 testProducto = new Product2(Name = 'Test Product 1');
        insert testProducto; // Crea el registro de producto y obtén su ID
        Product2 testProducto2 = new Product2(Name = 'Test Product 2');
        insert testProducto2; // Crea el registro de producto y obtén su ID

        // Crear una cuenta de prueba
        Account testAccount = new Account(Name = 'Test Account', Venta_Total_del_Mes__c = 250);
        insert testAccount;

        // Crear múltiples datos de prueba para Consumo_Actual__c
        Consumo_Actual__c consumo1 = new Consumo_Actual__c(
            Cuenta__c = testAccount.Id,
            Producto__c = testProducto.Id,
            Cantidad__c = 500,
            Precio__c = 100,
            Frecuencia__c = 1
        );
        
        Consumo_Actual__c consumo2 = new Consumo_Actual__c(
            Cuenta__c = testAccount.Id,
            Producto__c = testProducto2.Id,
            Cantidad__c = 500,
            Precio__c = 200,
            Frecuencia__c = 2
        );

        // Insertar los registros de Consumo_Actual__c
        insert new List<Consumo_Actual__c>{consumo1, consumo2};

        // Refrescar el objeto Account para obtener los valores actualizados
        testAccount = [SELECT Id, Consumo_actual_total__c, Venta_Total_del_Mes__c FROM Account WHERE Id = :testAccount.Id];

        // Inicializar el controlador con una instancia de StandardController SIN usar addFields
        Account refreshedAccount = [SELECT Id, Consumo_actual_total__c, Venta_Total_del_Mes__c FROM Account WHERE Id = :testAccount.Id];
        ApexPages.StandardController stdController = new ApexPages.StandardController(refreshedAccount);
        AccountMetricsController controller = new AccountMetricsController(stdController);

        // Empezar la prueba
        Test.startTest();

        // Llamadas a los métodos del controlador para obtener los valores calculados
        Decimal consumoTotal = controller.getConsumoActualTotal();
        Decimal ventaTotal = controller.getVentaTotalDelMes();
        String marketShare = controller.getMarketShare();

        // Finalizar la prueba
        Test.stopTest();

        // Realizar aserciones para verificar el comportamiento esperado
        System.assertEquals(150000, consumoTotal, 'El consumo total debería ser 150000.');
        System.assertEquals(250, ventaTotal, 'La venta total del mes debería ser 250.');
        System.assertEquals('0%', marketShare, 'El market share debería ser 0%.');
    }
}