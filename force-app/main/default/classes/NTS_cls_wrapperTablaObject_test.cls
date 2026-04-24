@IsTest
private class NTS_cls_wrapperTablaObject_test {
    
    @isTest static void wrapperTablaObjectTest() {
        Account anAccount = TEST_Setup.insertAccount('test');
        Product2 testProduct2 = TEST_Setup.createProduct2();
        insert testProduct2;
        Pricebook2 testPricebook2 = TEST_Setup.createStandardPricebook();
        insert anAccount;
        Order testOrder = TEST_Setup.createOrder(anAccount.Id,testPricebook2);
        insert testOrder;
        PricebookEntry testPricebookEntry = TEST_Setup.createPricebookEntry(testProduct2,testPricebook2);
        insert testPricebookEntry;
        OrderItem testOrderItem = TEST_Setup.createOrderItem(testOrder, testPricebookEntry);
        Insert testOrderItem;
        
		StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        mock.setStaticResource('MockInsercionCuenta');
        mock.setStatusCode(200);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
         String jsonExample = '{' +
            '"tipoRecord": "Tipo B",' +
            '"internaId": "56789",' +
            '"createdfrom": "12345",' +
            '"tranid": "INV987654",' +
            '"duedate": "2024-08-15",' +
            '"otherrefnum": "Ref456",' +
            '"trandate": "2024-07-20",' +
            '"nComprobante": "Comp789"' +
        '}';
        String respuesta1 = NTS_cls_WSnetsuiteInvoice.createInvoice(jsonExample);
        
        String jsonString1 = '{"tipoRecord":"Sales Order","internaId":"2","cost":"462","name":"123 Main St, Springfield, IL","productCode":"456","descripcion":"TEST","costoUSD":"10"}';
        String respuesta2 = NTS_cls_WSnetsuiteItem.createOrUpdteProd(jsonString1);
        
        String jsonString2 = '{"tipoRecord":"Sales Order","terms":"2","shipmethod":"462","billaddress":"123 Main St, Springfield, IL","shipaddress":"456 Elm St, Springfield, IL","shipdate":"19/07/2024","subsidiary":"USA","subtotal":"1000.00","taxtotal":"80.00","total":"1080.00","internaIdSale":"12345","entity":"1223","orderstatus":"A","trandate":"19/07/2024","itemList":[{"itemId":"1001","name":"Widget A","description":"A high-quality widget","quantity":"10","rate":"50.00","amount":"500.00","options":"None","unitslist":"Each","units":"10","custcol_l54_importe_exento":"0.00","custcol_l54_importe_total":"500.00","custcol_l54_importe_desc_gral":"0.00","tax1amt":"40.00","taxrate1":"8%","grossamt":"540.00"},{"itemId":"1002","name":"Widget B","description":"Another high-quality widget","quantity":10,"rate":50.00,"amount":500.00,"options":"None","unitslist":"Each","units":10,"custcol_l54_importe_exento":"0.00","custcol_l54_importe_total":500.00,"custcol_l54_importe_desc_gral":"0.00","tax1amt":"40.00","taxrate1":"8%","grossamt":"540.00"}],"tranid":"SO123456","moneda":"USD","exchangerate":"1.00","classProduct":"4","otherrefnum":"PO78910","contribuyente":"Taxpayer Name"}';
        String respuesta3 = NTS_cls_WSnetsuiteSalesOrder.createdOrUpdateSalesOrder(jsonString2);

        Test.stopTest();
    }
}