public class BnaCotizacionDolar {
    
    public static Decimal getCotizacionDolar() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://dolarapi.com/v1/dolares/oficial');
        req.setMethod('GET');
        req.setTimeout(20000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        String htmlBody = res.getBody();
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (Decimal) responseMap.get('venta');
    }
}