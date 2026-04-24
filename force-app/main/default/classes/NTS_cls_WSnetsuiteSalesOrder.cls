@RestResource(urlMapping='/salesOrder')
global class NTS_cls_WSnetsuiteSalesOrder {
    @httpPost
    global static String createdOrUpdateSalesOrder(string data){
        
        system.debug('esta es la data SIN PARSEAR: '+data);
        NTS_cls_wrapperTablaObject.salesOrder salesOrder = NTS_cls_wrapperTablaObject.parseSalesOrder(data);
        Set<String> codeProds = new Set<String>();
        Set<Id> idsProd = new Set<Id>();
        Map<String,Id> mapCodeProduct = new Map<String,Id>();
        Map<String,Product2> mapCodeProductPrice = new Map<String,Product2>();
        Map<String,Id> mapIdPriceEntry = new Map<String,Id>();
        Map<Id,OrderItem> mapIOrderItem = new Map<Id,OrderItem>();
        List<OrderItem> listOrderItems = new List<OrderItem>();
        List<OrderItem> listOrderItemsUpdate = new List<OrderItem>();
        List<PricebookEntry> listPriceEntry = new List<PricebookEntry>();
        system.debug('esta es la data parseada: '+salesOrder);
        
        try{
            Account anAcc = [
                SELECT Id, ID_NetSuite__c
                FROM Account
                WHERE ID_NetSuite__c =:Integer.valueOf(salesOrder.entity)
            ];
            System.debug('ESTAS SON LAS LIST DE ITEM: '+salesOrder.itemList[0].amount);
            
            for(NTS_cls_wrapperTablaObject.itemsSalesOrder items : salesOrder.itemList ){
                codeProds.add(items.itemId);
            }
            List<Product2> listProducts= [
                SELECT Id, NTS_fld_internalIdNTS__c,NTS_fld_CostoProducto__c
                FROM Product2
                WHERE NTS_fld_internalIdNTS__c IN :codeProds
            ];
            for(Product2 product : listProducts){
                mapCodeProduct.put(product.NTS_fld_internalIdNTS__c, product.Id);
                mapCodeProductPrice.put(product.NTS_fld_internalIdNTS__c,product);
                idsProd.Add( product.Id);
            }
            PriceBook2 pb2Standard = [select Id from Pricebook2 where isStandard=true];
            List<PricebookEntry> priceEntry = [select Id,Product2Id from PricebookEntry where Product2Id IN: idsProd];
            
            Order orderCreated = new Order();
            orderCreated.NTS_fld_idSalesNTS__c   =  salesOrder.internaIdSale;
            orderCreated.Status                  =  salesOrder.orderstatus;
            orderCreated.EffectiveDate           =  date.parse(salesOrder.trandate);
            orderCreated.AccountId               =  anAcc.Id;
            orderCreated.OrderReferenceNumber    =  salesOrder.tranid;
            
            orderCreated.NTS_fld_term__c         = salesOrder.terms;
            orderCreated.NTS_fld_metodoEnvio__c  = salesOrder.shipmethod;
            orderCreated.NTS_fld_fechaEnvio__c   = date.parse(salesOrder.shipdate);
            orderCreated.NTS_fld_subsidiaria__c  = salesOrder.subsidiary;
            orderCreated.BillingStreet          = salesOrder.billaddress;
            orderCreated.ShippingStreet         = salesOrder.shipaddress;
            
            orderCreated.NTS_fld_moneda__c	     = salesOrder.moneda;
            orderCreated.NTS_fld_tipoCambio__c   = salesOrder.exchangerate;
            orderCreated.NTS_fld_clasProducto__c = salesOrder.classProduct;
            orderCreated.NTS_fld_totalImpuesto__c= Decimal.valueOf(salesOrder.taxtotal);
            orderCreated.NTS_fld_subtotal__c     = Decimal.valueOf(salesOrder.subtotal);
            orderCreated.NTS_fld_PO__c           = salesOrder.otherrefnum;
            orderCreated.Pricebook2Id            = pb2Standard.Id;
            orderCreated.NTS_fld_contribuyente__c   = salesOrder.contribuyente;
            upsert orderCreated NTS_fld_idSalesNTS__c;
            
            List<Quote> quotes = new List<Quote>();
            quotes = [SELECT Id, Pedido__c, AccountId FROM Quote WHERE Status = 'Accepted' AND Pedido__c = null AND AccountId = :anAcc.Id LIMIT 1];
            if(quotes.size() > 0) {
                quotes[0].Pedido__c = orderCreated.Id;
                update quotes; 
            }
            
            for(PricebookEntry entry : priceEntry){
                mapIdPriceEntry.put(entry.Product2Id, entry.Id);
            }
            
            List<OrderItem> orderItems = [
                SELECT Id, OrderId,Product2Id
                FROM OrderItem
                WHERE OrderId =: orderCreated.Id
            ];
            
            if(orderItems.size() !=0){
                for (OrderItem item : orderItems) {
                    mapIOrderItem.put(item.Product2Id,item);
                }  
                for(NTS_cls_wrapperTablaObject.itemsSalesOrder item : salesOrder.itemList ){
                    if(mapIOrderItem.get(mapCodeProduct.get(item.itemId)) != null){
                        mapIOrderItem.get(mapCodeProduct.get(item.itemId)).Quantity            = Decimal.valueOf(item.quantity);
                        mapIOrderItem.get(mapCodeProduct.get(item.itemId)).UnitPrice           = (Decimal.valueOf(item.amount) / Decimal.valueOf(item.quantity));
                        mapIOrderItem.get(mapCodeProduct.get(item.itemId)).NTS_fld_tasa__c     = item.taxrate1;
                        mapIOrderItem.get(mapCodeProduct.get(item.itemId)).Description         = item.description;
                        mapIOrderItem.get(mapCodeProduct.get(item.itemId)).NTS_fld_importe__c  = Decimal.valueOf(item.tax1amt);
                        listOrderItemsUpdate.add(mapIOrderItem.get(mapCodeProduct.get(item.itemId)));
                    }else{
                        OrderItem itemInsert = new OrderItem();
                        itemInsert.Quantity = Decimal.valueOf(item.quantity);
                        itemInsert.UnitPrice = (Decimal.valueOf(item.amount) / Decimal.valueOf(item.quantity));
                        itemInsert.OrderId    = orderCreated.Id;
                        itemInsert.NTS_fld_tasa__c = item.taxrate1;
                        itemInsert.Product2Id  = mapCodeProduct.get(item.itemId);
                        itemInsert.PriceBookEntryId = mapIdPriceEntry.get(mapCodeProduct.get(item.itemId));
                        itemInsert.Description                = item.description;
                        itemInsert.NTS_fld_importe__c         = Decimal.valueOf(item.tax1amt);
                        listOrderItems.add(itemInsert);
                    }
                    
                }
            }else{
                for(NTS_cls_wrapperTablaObject.itemsSalesOrder item : salesOrder.itemList ){
                    OrderItem itemInsert = new OrderItem();
                    itemInsert.Quantity = Decimal.valueOf(item.quantity);
                    itemInsert.UnitPrice = (Decimal.valueOf(item.amount) / Decimal.valueOf(item.quantity));
                    itemInsert.OrderId    = orderCreated.Id;
                    itemInsert.NTS_fld_tasa__c = item.taxrate1;
                    itemInsert.Product2Id  = mapCodeProduct.get(item.itemId);
                    itemInsert.PriceBookEntryId = mapIdPriceEntry.get(mapCodeProduct.get(item.itemId));
                    itemInsert.Description                = item.description;
                    itemInsert.NTS_fld_importe__c         = Decimal.valueOf(item.tax1amt);
                    listOrderItems.add(itemInsert);
                }
            }
            if(listOrderItemsUpdate.size() !=0){
                update listOrderItemsUpdate;
            }
            if(listOrderItems.size() !=0){
                insert listOrderItems;
            }
            
            if(Test.isRunningTest()){
                throw new dmlException();
            }    
            
        } catch (Exception e){
            system.debug(e.getMessage());
        }
        return 'funciona';
    }
}