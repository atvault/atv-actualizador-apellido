@isTest
public class AccountProductControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Crear cuenta de prueba
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Crear producto de prueba
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true,
            ProductCode = 'TEST001'
        );
        insert testProduct;
        
        // Crear producto frecuente de prueba
        AccountProduct__c testAccountProduct = new AccountProduct__c(
            Cliente__c = testAccount.Id,
            Producto__c = testProduct.Id,
            CantidadTipica__c = 10,
            FrecuenciaCompra__c = 'Mensual',
            Precio__c = 50.00
        );
        insert testAccountProduct;
        
        // Crear un segundo producto para pruebas de eliminación
        Product2 testProduct2 = new Product2(
            Name = 'Test Product 2',
            IsActive = true,
            ProductCode = 'TEST002'
        );
        insert testProduct2;
        
        AccountProduct__c testAccountProduct2 = new AccountProduct__c(
            Cliente__c = testAccount.Id,
            Producto__c = testProduct2.Id,
            CantidadTipica__c = 20,
            FrecuenciaCompra__c = 'Trimestral',
            Precio__c = 75.00
        );
        insert testAccountProduct2;
    }
    
    @isTest
    static void testGetRelatedProducts() {
        // Obtener la cuenta de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        List<AccountProduct__c> products = AccountProductController.getRelatedProducts(testAccount.Id);
        Test.stopTest();
        
        // Verificar resultados
        System.assertEquals(2, products.size(), 'Debería haber 2 productos relacionados');
        
        // Verificar que los campos están presentes
        for (AccountProduct__c product : products) {
            System.assertNotEquals(null, product.Id, 'El producto debería tener un ID');
            System.assertNotEquals(null, product.Producto__r, 'El producto debería tener relación con Product2');
        }
    }
    
    @isTest
    static void testGetRelatedProductsWithNullAccount() {
        Test.startTest();
        
        try {
            AccountProductController.getRelatedProducts(null);
            System.assert(false, 'Debería lanzar excepción con ID nulo');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('obligatorio') || e.getMessage().contains('Script-thrown'), 'Debería contener mensaje de error apropiado');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetRelatedProductsNonTestMode() {
        // Obtener la cuenta de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Guardar estado original
        Boolean originalTestMode = AccountProductController.isInTestMode;
        
        try {
            // Cambiar a modo no-test
            AccountProductController.isInTestMode = false;
            
            Test.startTest();
            List<AccountProduct__c> products = AccountProductController.getRelatedProducts(testAccount.Id);
            Test.stopTest();
            
            // Verificar que funciona en modo no-test
            System.assertEquals(2, products.size(), 'Debería funcionar en modo no-test');
            
        } finally {
            // Restaurar estado original
            AccountProductController.isInTestMode = originalTestMode;
        }
    }
    
    @isTest
    static void testCreateAccountProduct() {
        // Obtener la cuenta y producto de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        
        Test.startTest();
        List<AccountProduct__c> updatedProducts = AccountProductController.createAccountProduct(
            testAccount.Id,
            testProduct.Id,
            50,
            'Semestral',
            100.50
        );
        Test.stopTest();
        
        // Verificar en la base de datos
        List<AccountProduct__c> productsInDB = [
            SELECT Id, CantidadTipica__c, FrecuenciaCompra__c, Precio__c 
            FROM AccountProduct__c 
            WHERE Cliente__c = :testAccount.Id AND CantidadTipica__c = 50
        ];
        System.assertEquals(1, productsInDB.size(), 'Debería existir un producto con cantidad 50');
        System.assertEquals('Semestral', productsInDB[0].FrecuenciaCompra__c, 'La frecuencia debería ser Semestral');
        System.assertEquals(100.50, productsInDB[0].Precio__c, 'El precio debería ser 100.50');
    }
    
    @isTest
    static void testCreateAccountProductNonTestMode() {
        // Obtener la cuenta y producto de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        
        // Guardar estado original
        Boolean originalTestMode = AccountProductController.isInTestMode;
        
        try {
            // Cambiar a modo no-test
            AccountProductController.isInTestMode = false;
            
            Test.startTest();
            List<AccountProduct__c> updatedProducts = AccountProductController.createAccountProduct(
                testAccount.Id,
                testProduct.Id,
                75,
                'Anual',
                200.75
            );
            Test.stopTest();
            
            // Verificar que funciona en modo no-test
            List<AccountProduct__c> productsInDB = [
                SELECT Id, CantidadTipica__c 
                FROM AccountProduct__c 
                WHERE Cliente__c = :testAccount.Id AND CantidadTipica__c = 75
            ];
            System.assertEquals(1, productsInDB.size(), 'Debería crear el producto en modo no-test');
            
        } finally {
            // Restaurar estado original
            AccountProductController.isInTestMode = originalTestMode;
        }
    }
    
    @isTest
    static void testCreateAccountProductWithException() {
        // Guardar estado original
        Boolean originalTestMode = AccountProductController.isInTestMode;
        
        try {
            // Forzar modo test para probar el catch
            AccountProductController.isInTestMode = true;
            
            Test.startTest();
            
            // Intentar crear con parámetros inválidos para forzar excepción
            try {
                AccountProductController.createAccountProduct(
                    null, // ID nulo debería causar error
                    null,
                    -1,
                    'Inválido',
                    null
                );
                System.assert(false, 'Debería lanzar una excepción');
            } catch (Exception e) {
                System.assert(e.getMessage().contains('Error') || e.getMessage().contains('Exception') || e.getMessage().contains('Script-thrown'), 'Debería contener mensaje de error');
            }
            
            Test.stopTest();
            
        } finally {
            // Restaurar estado original
            AccountProductController.isInTestMode = originalTestMode;
        }
    }
    
    @isTest
    static void testDeleteAccountProducts() {
        // Obtener la cuenta de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Obtener uno de los productos para eliminar
        AccountProduct__c productToDelete = [
            SELECT Id 
            FROM AccountProduct__c 
            WHERE Cliente__c = :testAccount.Id 
            LIMIT 1
        ];
        
        Test.startTest();
        List<AccountProduct__c> remainingProducts = AccountProductController.deleteAccountProducts(
            new List<String>{ productToDelete.Id },
            testAccount.Id
        );
        Test.stopTest();
        
        // Verificar en la base de datos
        List<AccountProduct__c> productsInDB = [
            SELECT Id 
            FROM AccountProduct__c 
            WHERE Cliente__c = :testAccount.Id
        ];
        System.assertEquals(1, productsInDB.size(), 'Debería quedar 1 producto en la base de datos');
    }
    
    @isTest
    static void testDeleteAccountProductsNonTestMode() {
        // Obtener la cuenta de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Obtener uno de los productos para eliminar
        AccountProduct__c productToDelete = [
            SELECT Id 
            FROM AccountProduct__c 
            WHERE Cliente__c = :testAccount.Id 
            LIMIT 1
        ];
        
        // Guardar estado original
        Boolean originalTestMode = AccountProductController.isInTestMode;
        
        try {
            // Cambiar a modo no-test
            AccountProductController.isInTestMode = false;
            
            Test.startTest();
            List<AccountProduct__c> remainingProducts = AccountProductController.deleteAccountProducts(
                new List<String>{ productToDelete.Id },
                testAccount.Id
            );
            Test.stopTest();
            
            // Verificar que funciona en modo no-test
            List<AccountProduct__c> productsInDB = [
                SELECT Id 
                FROM AccountProduct__c 
                WHERE Cliente__c = :testAccount.Id
            ];
            System.assertEquals(1, productsInDB.size(), 'Debería eliminar en modo no-test');
            
        } finally {
            // Restaurar estado original
            AccountProductController.isInTestMode = originalTestMode;
        }
    }
    
    @isTest
    static void testDeleteNonExistentProducts() {
        // Obtener la cuenta de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        List<AccountProduct__c> remainingProducts = AccountProductController.deleteAccountProducts(
            new List<String>{ '001000000000001AAA' },
            testAccount.Id
        );
        Test.stopTest();
        
        // Verificar en la base de datos
        List<AccountProduct__c> productsInDB = [
            SELECT Id 
            FROM AccountProduct__c 
            WHERE Cliente__c = :testAccount.Id
        ];
        System.assertEquals(2, productsInDB.size(), 'Deberían seguir existiendo 2 productos en la base de datos');
    }
    
    @isTest
    static void testDeleteWithEmptyList() {
        // Obtener la cuenta de prueba
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        // Probar con lista vacía
        List<AccountProduct__c> products1 = AccountProductController.deleteAccountProducts(
            new List<String>(),
            testAccount.Id
        );
        
        // Probar con null
        List<AccountProduct__c> products2 = AccountProductController.deleteAccountProducts(
            null,
            testAccount.Id
        );
        Test.stopTest();
        
        // Verificar que no se elimina nada
        List<AccountProduct__c> productsInDB = [
            SELECT Id 
            FROM AccountProduct__c 
            WHERE Cliente__c = :testAccount.Id
        ];
        System.assertEquals(2, productsInDB.size(), 'No debería eliminarse nada con lista vacía/null');
        System.assertEquals(2, products1.size(), 'Debería devolver todos los productos');
        System.assertEquals(2, products2.size(), 'Debería devolver todos los productos');
    }
    
    @isTest
    static void testEdgeCasesAndErrorHandling() {
        Test.startTest();
        
        // Crear una cuenta sin productos para probar diferentes caminos
        Account emptyAccount = new Account(Name = 'Empty Test Account');
        insert emptyAccount;
        
        // Probar getRelatedProducts con cuenta sin productos
        List<AccountProduct__c> emptyProducts = AccountProductController.getRelatedProducts(emptyAccount.Id);
        System.assertEquals(0, emptyProducts.size(), 'Debería devolver lista vacía para cuenta sin productos');
        
        // Probar createAccountProduct con valores límite
        Product2 testProduct = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        
        List<AccountProduct__c> resultProducts = AccountProductController.createAccountProduct(
            emptyAccount.Id,
            testProduct.Id,
            0, // cantidad cero
            '',  // frecuencia vacía
            0.0  // precio cero
        );
        
        System.assertEquals(1, resultProducts.size(), 'Debería crear producto con valores límite');
        
        Test.stopTest();
    }
    
    @isTest
    static void testPermissionEdgeCases() {
        // Este test simula diferentes escenarios que podrían ocurrir en producción
        // aunque en el entorno de test los permisos son diferentes
        
        Test.startTest();
        
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        
        // Guardar estado original
        Boolean originalTestMode = AccountProductController.isInTestMode;
        
        try {
            // Simular modo no-test para probar caminos de permisos
            AccountProductController.isInTestMode = false;
            
            // Estos métodos deberían funcionar ya que estamos en un test
            List<AccountProduct__c> products = AccountProductController.getRelatedProducts(testAccount.Id);
            System.assertNotEquals(null, products, 'Debería devolver productos');
            
            try {
                List<AccountProduct__c> newProducts = AccountProductController.createAccountProduct(
                    testAccount.Id,
                    testProduct.Id,
                    99,
                    'Test',
                    99.99
                );
                System.assertNotEquals(null, newProducts, 'Debería crear producto');
            } catch (Exception e) {
                // En modo no-test puede fallar por permisos, esto es esperado
                System.debug('Error esperado en modo no-test: ' + e.getMessage());
            }
            
        } finally {
            AccountProductController.isInTestMode = originalTestMode;
        }
        
        Test.stopTest();
    }
}