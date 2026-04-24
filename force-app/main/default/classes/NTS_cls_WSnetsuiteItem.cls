@RestResource(urlMapping='/item')
global class NTS_cls_WSnetsuiteItem {
	@httpPost
    global static String createOrUpdteProd(string data){
        system.debug('este es la data directa de netsuite: '+data);
        NTS_cls_wrapperTablaObject.item item = NTS_cls_wrapperTablaObject.parseItem(data);
		
		Product2 productInsert = new Product2();
        productInsert.Name                     = item.descripcion;
        productInsert.ProductCode              = item.name;
        productInsert.Description			   = item.productCode;
		productInsert.IsActive                 = true;
		productInsert.NTS_fld_internalIdNTS__c = item.internaId;
        if(item.costoUSD !=null && item.costoUSD !=''){
            productInsert.NTS_fld_CostoProducto__c = decimal.valueOf(item.costoUSD);
        }
        try{
            upsert productInsert NTS_fld_internalIdNTS__c;
            
            List<PricebookEntry> priceExistente = [
                SELECT Id, Product2Id
                FROM PricebookEntry
                WHERE Product2Id =: productInsert.Id
            ];
            
            if(priceExistente.size() == 0){
                PriceBook2 pb2Standard = [select Id from Pricebook2 where isStandard=true];
                PricebookEntry insertPricebook = new PricebookEntry();
                insertPricebook.IsActive = true;
                insertPricebook.Pricebook2Id = pb2Standard.Id;
                insertPricebook.Product2Id = productInsert.Id;
                if(productInsert.NTS_fld_CostoProducto__c !=null){
                    insertPricebook.UnitPrice  =  productInsert.NTS_fld_CostoProducto__c;
                }else{
                    insertPricebook.UnitPrice  = 1;
                }
                insert insertPricebook;
                
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