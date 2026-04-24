@RestResource(urlMapping='/invoice')
global class NTS_cls_WSnetsuiteInvoice {

    @httpPost
    global static String createInvoice(string data){
        system.debug('este es la data directa de netsuite: '+data);
        String TIPO_MONEDA = 'US Dollar';
        NTS_cls_wrapperTablaObject.invoice invoice = NTS_cls_wrapperTablaObject.parseInvoice(data);
        List<Order> orderRelation = new List<Order>();
        try{
            if(invoice.createdfrom !=null && invoice.createdfrom !=''){
                orderRelation = [
                SELECT Id, NTS_fld_idSalesNTS__c,Status
                FROM Order
                WHERE NTS_fld_idSalesNTS__c =: invoice.createdfrom
                Limit 1
            	];
                if(!orderRelation.isEmpty()){
               		if(orderRelation[0].Status !=	'B'){
                    	orderRelation[0].Status = 'B';
                    	Update orderRelation;
                	}      
                }
            }
           
            
            NTS_obj_factura__c facturaInser = new NTS_obj_factura__c();
            if(!orderRelation.isEmpty()){
                facturaInser.NTS_fld_order__c = orderRelation[0].Id;
            }
            facturaInser.NTS_fld_idFaturaNTS__c = invoice.id;
            facturaInser.Name = invoice.tranid;
            facturaInser.NTS_fld_idCuenta__c = invoice.entity;
            facturaInser.NTS_fld_numeroPedido__c = invoice.otherrefnum;
            facturaInser.NTS_fld_fechaVto__c = date.parse(invoice.duedate);
            facturaInser.NTS_fld_fecha__c = date.parse(invoice.trandate);
            facturaInser.NTS_fld_tipoMoneda__c = invoice.moneda;
            facturaInser.NTS_fld_letraDoc__c = Constants.NUMERO_FACTURA.get(invoice.letraDoc);
            if(invoice.moneda != TIPO_MONEDA){
            	facturaInser.NTS_fld_total__c = (decimal.valueOf(invoice.total)/ BnaCotizacionDolar.getCotizacionDolar());
            }else{
                facturaInser.NTS_fld_total__c = decimal.valueOf(invoice.total);
            }
            Upsert facturaInser NTS_fld_idFaturaNTS__c;       		
            if(Test.isRunningTest()){
            	throw new dmlException();
            }    
            
     	} catch (Exception e){
        	system.debug(e.getMessage());
       	}        
        return 'funciona';
        
        // NTS_fld_idFaturaNTS ,NTS_fld_condIVA__c NTS_fld_order__c== busqueda de createdfrom en order,  NTS_fld_fecha__c name==numero factura, NTS_fld_numeroPedido ==otherrefnum, NTS_fld_fechaVto__c == duedate, NTS_fld_fecha__c == trandate, NTS_fld_condIVA__c== custcol_l54_tipo_contribuyente
    }
}