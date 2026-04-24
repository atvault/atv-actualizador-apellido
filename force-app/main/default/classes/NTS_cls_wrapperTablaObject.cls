public class NTS_cls_wrapperTablaObject {
	public static NTS_cls_wrapperTablaObject.salesOrder parseSalesOrder(String json) {            
        return (NTS_cls_wrapperTablaObject.salesOrder) System.JSON.deserialize(json, salesOrder.class);
    }
    public static NTS_cls_wrapperTablaObject.item parseItem(String json) {            
        return (NTS_cls_wrapperTablaObject.item) System.JSON.deserialize(json, item.class);
    }
    public static NTS_cls_wrapperTablaObject.invoice parseInvoice(String json) {            
        return (NTS_cls_wrapperTablaObject.invoice) System.JSON.deserialize(json, invoice.class);
    }
  	public with sharing class salesOrder{
        public String tipoRecord;
   	 	public String terms;
        public String shipmethod;
        public String billaddress;
        public String shipaddress;
        public String shipdate;
        public String subsidiary;
        public String subtotal;
        public String taxtotal;
   	 	public String total;
        public String internaIdSale;
        public String entity;
        public String orderstatus;
        public String trandate;
        public List<NTS_cls_wrapperTablaObject.itemsSalesOrder> itemList;
        public String tranid;
        public String moneda;
        public String exchangerate;
        public String classProduct;
        public String otherrefnum;
        public String contribuyente;
    }  

    public with sharing class itemsSalesOrder{
		public String itemId;
   	 	public String name;
        public String description;
        public String quantity;
        public String rate;
        public String amount;
        public String options;
        public String unitslist;
        public String units;
   	 	public String custcol_l54_importe_exento;
        public String custcol_l54_importe_total;
        public String custcol_l54_importe_desc_gral;
        public String tax1amt;
        public String taxrate1;
        public String grossamt;
	}
    public with sharing class item{
        public String tipoRecord;
        public String internaId;
        public String cost;
        public String name;
        public String productCode;
        public String descripcion;
        public String costoUSD;
    }
    public with sharing class invoice{
        public String tipoRecord;
        public String internaId;
        public String createdfrom;
        public String tranid;
        public String duedate;
        public String otherrefnum;
        public String trandate;
        public String nComprobante;
        public String moneda;
        public String total;
        public String initialtranid;
        public String id;
        public String entity;
		public String letraDoc;
    }
}