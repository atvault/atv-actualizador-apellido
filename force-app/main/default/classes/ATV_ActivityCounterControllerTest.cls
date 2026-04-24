/**
 * @description: Test class for ATV_ActivityCounterController
 * @author: AT Vault
 */
@isTest
private class ATV_ActivityCounterControllerTest {
    
    /**
     * @description: Tests the controller's event counter method
     */
    @isTest
    static void testRunEventCounter() {
        // Create controller instance
        ATV_ActivityCounterController controller = new ATV_ActivityCounterController();
        
        // Start test context
        Test.startTest();
        
        // Call the method
        PageReference result = controller.runEventCounter();
        
        Test.stopTest();
        
        // Verify the method returns null (stay on same page)
        System.assertEquals(null, result, 'Method should return null');
        
        // Verify a message was added
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertNotEquals(0, messages.size(), 'At least one message should be added');
        
        // Verify the message is an INFO message
        Boolean hasInfoMessage = false;
        for (ApexPages.Message msg : messages) {
            if (msg.getSeverity() == ApexPages.Severity.INFO) {
                hasInfoMessage = true;
                break;
            }
        }
        System.assertEquals(true, hasInfoMessage, 'An INFO message should be added');
    }
    
    /**
     * @description: Tests the controller's task counter method
     */
    @isTest
    static void testRunTaskCounter() {
        // Create controller instance
        ATV_ActivityCounterController controller = new ATV_ActivityCounterController();
        
        // Start test context
        Test.startTest();
        
        // Call the method
        PageReference result = controller.runTaskCounter();
        
        Test.stopTest();
        
        // Verify the method returns null (stay on same page)
        System.assertEquals(null, result, 'Method should return null');
        
        // Verify a message was added
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertNotEquals(0, messages.size(), 'At least one message should be added');
        
        // Verify the message is an INFO message
        Boolean hasInfoMessage = false;
        for (ApexPages.Message msg : messages) {
            if (msg.getSeverity() == ApexPages.Severity.INFO) {
                hasInfoMessage = true;
                break;
            }
        }
        System.assertEquals(true, hasInfoMessage, 'An INFO message should be added');
    }
    
    /**
     * @description: Tests the controller's full counter method
     */
    @isTest
    static void testRunFullCounter() {
        // Create controller instance
        ATV_ActivityCounterController controller = new ATV_ActivityCounterController();
        
        // Start test context
        Test.startTest();
        
        // Call the method
        PageReference result = controller.runFullCounter();
        
        Test.stopTest();
        
        // Verify the method returns null (stay on same page)
        System.assertEquals(null, result, 'Method should return null');
        
        // Verify a message was added
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertNotEquals(0, messages.size(), 'At least one message should be added');
        
        // Verify the message is an INFO message
        Boolean hasInfoMessage = false;
        for (ApexPages.Message msg : messages) {
            if (msg.getSeverity() == ApexPages.Severity.INFO) {
                hasInfoMessage = true;
                break;
            }
        }
        System.assertEquals(true, hasInfoMessage, 'An INFO message should be added');
    }
}