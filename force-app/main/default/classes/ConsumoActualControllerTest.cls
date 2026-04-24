@isTest
private class ConsumoActualControllerTest {
    
    static testMethod void testAddAndSaveConsumoActual() {
        // Suponiendo que tienes un objeto de Producto (ajusta el API Name según tu modelo)
        Product2 testProducto = new Product2(Name = 'Test Product 1');
        insert testProducto; // Crea el registro de producto y obtén su ID
        Product2 testProducto2 = new Product2(Name = 'Test Product 2');
        insert testProducto2; // Crea el registro de producto y obtén su ID
        
        // Crear datos de prueba para Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Crear múltiples datos de prueba para Consumo_Actual__c
        List<Consumo_Actual__c> testConsumos = new List<Consumo_Actual__c>{
            new Consumo_Actual__c(
                Cuenta__c = testAccount.Id,
                Producto__c = testProducto.Id,
                Cantidad__c = 1,
                Precio__c = 100,
                Frecuencia__c = 1
            ),
            new Consumo_Actual__c(
                Cuenta__c = testAccount.Id,
                Producto__c = testProducto2.Id,
                Cantidad__c = 2,
                Precio__c = 200,
                Frecuencia__c = 2
            )
        };
        insert testConsumos; // Inserta la lista de consumos

        // Inicializar el controlador con una instancia de StandardController
        ApexPages.StandardController sc = new ApexPages.StandardController(testAccount);
        ConsumoActualController controller = new ConsumoActualController(sc);

        // Empezar la prueba
        Test.startTest();

        // Ejecutar métodos del controlador
        controller.addNewConsumoActual(); // Agregar un nuevo consumo
        PageReference pageRef = controller.save(); // Intentar guardar la lista de consumos

        // Finalizar la prueba
        Test.stopTest();

        // Realizar aserciones para verificar el comportamiento esperado
        System.assertEquals(3, controller.consumos.size(), 'Debería haber tres registros de Consumo_Actual__c.');
        System.assertNotEquals(null, pageRef, 'Debería retornar una PageReference.');
        System.assert(pageRef.getUrl().contains(testAccount.Id), 'La URL debería contener el ID del account.');
    }
}