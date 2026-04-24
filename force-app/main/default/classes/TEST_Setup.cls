@IsTest
public class TEST_Setup {
	public static Account insertAccount(String name) {
        Account testAccount = new Account();
        testAccount.Name = name;
        testAccount.Email__c = 'test@test.com';
        testAccount.Phone = '1283612783';
        testAccount.ID_NetSuite__c = 1223;
        testAccount.CUIT__c = 23132121212L;
        return testAccount;
    }
    public static Contact insertContact(String name, String id) {
        Contact testContact = new Contact();
        testContact.LastName = name;
        testContact.AccountId = id;
        return testContact;
    }
    
    public static Opportunity insertOpportunity(String name, String contactId, String accountId) {
        Opportunity testOpportunity = new Opportunity();
        testOpportunity.Name = name;
        testOpportunity.ContactId = contactId;
        testOpportunity.AccountId = accountId;
        testOpportunity.Amount = 25000;
        testOpportunity.CloseDate = Date.today();
        testOpportunity.StageName = 'MQL';
        return testOpportunity;
    }
    /*
    public static Quote insertQuote(String name, String id) {
        Contact testContact = new Contact();
        testContact.LastName = name;
        testContact.AccountId = id;
        return testContact;
    }*/
    public static Pricebook2 createStandardPricebook() {

		Id pricebookId = Test.getStandardPricebookId();
		Pricebook2 standardPricebook = new Pricebook2(
    	Id = pricebookId,
    	IsActive = true
		);
		update standardPricebook;        

        return standardPricebook;
    }
    public static Product2 createProduct2() {

		Product2 product = new Product2(
            Name = 'Test Product',
            ProductCode = 'TP123',
            Description = 'This is a test product',
            IsActive = true,
            NTS_fld_internalIdNTS__c = '1001'
        );
        return product;  
    }
    public static Order createOrder(Id idAccount, Pricebook2 standardPricebook) {
		
		Order orderTest = new Order(
            Status  = 'A',
            NTS_fld_idSalesNTS__c = '12345',
            AccountId = idAccount,
            EffectiveDate =  Date.today(),
            Pricebook2Id = standardPricebook.Id
        );
        return orderTest;  
    }
    public static PricebookEntry createPricebookEntry(Product2 testProduct, Pricebook2 standardPricebook) {
		
		PricebookEntry testPricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        return testPricebookEntry;  
    }
    public static OrderItem createOrderItem(Order testOrder, PricebookEntry testPricebookEntry) {
		
		OrderItem testOrderItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = testPricebookEntry.Id,
            Quantity = 2,
            UnitPrice = 100.00
        );

        return testOrderItem;  
    }
}