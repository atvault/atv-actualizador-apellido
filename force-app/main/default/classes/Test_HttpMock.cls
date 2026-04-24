@IsTest
public class Test_HttpMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/xml');
        res.setBody('<root/>');
        return res;
    }
}