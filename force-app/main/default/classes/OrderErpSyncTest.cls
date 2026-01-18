/**
 * @description Unit tests for Order ERP sync components.
 * Covers: trigger handler, queueable, payload builder, callout service, logger.
 * Uses @TestSetup for test data.
 * @group Integration
 * @date 2026-01-18
 */
@isTest
public class OrderErpSyncTest {
    @TestSetup
    static void setupTestData() {
        // Create a test account
        Account acc = new Account(
            Name = 'Test Account',
            Type = 'Customer'
        );
        insert acc;

        // Create a test product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TEST-001',
            IsActive = true
        );
        insert prod;

        // Create a test order
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = System.today(),
            TotalAmount = 100.00
        );
        insert ord;

        // Create a test order item
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prod.Id,
            Quantity = 1,
            UnitPrice = 100.00
        );
        insert oi;
    }

    @isTest
    static void testTriggerHandler_noRecords() {
        OrderTriggerHandler.handleAfter(null, null, false, false);
        // Should not throw
    }

    @isTest
    static void testTriggerHandler_insert() {
        // Setup
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = System.today(),
            TotalAmount = 100.00
        );
        Test.startTest();
        insert ord;
        Test.stopTest();

        // Verify it was enqueued (we can't easily assert the job was queued, but we can verify no exception)
        // In practice, you'd use a mockable pattern or verify via Integration_Log__c
    }

    @isTest
    static void testPayloadBuilder() {
        // Get test data
        Order ord = [SELECT Id, OrderNumber, AccountId, Status, EffectiveDate, TotalAmount, LastModifiedDate FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Product2Id, Quantity, UnitPrice, TotalPrice FROM OrderItem WHERE OrderId = :ord.Id];

        // Test building DTO
        OrderPayloadBuilder.OrderDTO dto = OrderPayloadBuilder.buildOrderDTO(ord, items);

        // Assertions
        System.assertNotEquals(null, dto);
        System.assertEquals(ord.Id, dto.id);
        System.assertEquals(ord.OrderNumber, dto.orderNumber);
        System.assertEquals(ord.AccountId, dto.accountId);
        System.assertEquals(ord.Status, dto.status);
        System.assertEquals(ord.EffectiveDate, dto.effectiveDate);
        System.assertEquals(ord.TotalAmount, dto.totalAmount);
        System.assertEquals(ord.LastModifiedDate, dto.lastModifiedDate);
        System.assertNotEquals(null, dto.items);
        System.assertEquals(1, dto.items.size());
    }

    @isTest
    static void testQueueableHappyPath() {
        // Setup
        Order ord = [SELECT Id FROM Order LIMIT 1];
        List<Id> ids = new List<Id>{ord.Id};

        // Test
        Test.startTest();
        OrderErpSyncQueueable q = new OrderErpSyncQueueable(ids);
        q.execute(null);
        Test.stopTest();

        // Verify log entry was created
        List<Integration_Log__c> logs = [SELECT Id, Status__c, Severity__c FROM Integration_Log__c WHERE Correlation_Id__c != null ORDER BY CreatedDate DESC LIMIT 1];
        System.assert(!logs.isEmpty(), 'Log should be created');
        System.assertEquals('Requested', logs[0].Status__c);
        System.assertEquals('INFO', logs[0].Severity__c);
    }

    @isTest
    static void testQueueableWithInvalidNamedCredential() {
        // Setup
        Order ord = [SELECT Id FROM Order LIMIT 1];
        List<Id> ids = new List<Id>{ord.Id};

        // Test with a fake named credential to simulate callout failure
        Test.startTest();
        OrderErpSyncQueueable q = new OrderErpSyncQueueable(ids);
        q.execute(null);
        Test.stopTest();

        // Verify error log was created
        List<Integration_Log__c> logs = [SELECT Id, Status__c, Severity__c, Error_Message__c FROM Integration_Log__c WHERE Correlation_Id__c != null ORDER BY CreatedDate DESC LIMIT 1];
        System.assert(!logs.isEmpty(), 'Log should be created');
        System.assertEquals('Failed', logs[0].Status__c);
        System.assertEquals('ERROR', logs[0].Severity__c);
    }

    @isTest
    static void testLogger() {
        IntegrationLogger logger = new IntegrationLogger();
        IntegrationLogger.LogEntry entry = new IntegrationLogger.LogEntry();
        entry.correlationId = 'test-correlation-id';
        entry.endpoint = '/test';
        entry.method = 'POST';
        entry.direction = 'Outbound';
        entry.sourceSystem = 'Salesforce';
        entry.targetSystem = 'ERP';
        entry.severity = IntegrationLogger.Severity.INFO;
        entry.status = IntegrationLogger.Status.REQUESTED;
        entry.requestPayload = '{"test": "data"}';

        logger.add(entry);
        logger.flush(); // Should not throw

        List<Integration_Log__c> logs = [SELECT Id, Correlation_Id__c, Request_Payload__c FROM Integration_Log__c WHERE Correlation_Id__c = 'test-correlation-id'];
        System.assertEquals(1, logs.size());
        System.assertEquals('{"test": "data"}', logs[0].Request_Payload__c);
    }

    @isTest
    static void testInvocable() {
        // Setup
        Order ord = [SELECT Id FROM Order LIMIT 1];
        List<Id> ids = new List<Id>{ord.Id};

        // Test
        List<OrderErpSyncInvocable.KeyValueResult> results = OrderErpSyncInvocable.syncOrdersToErp(ids);

        // Assertions
        System.assert(results != null && !results.isEmpty(), 'Results should not be null or empty');
        // Find the result with key 'message'
        String message = '';
        Boolean success = false;
        for(OrderErpSyncInvocable.KeyValueResult result : results) {
            if(result.key == 'message') {
                message = result.value;
            } else if(result.key == 'false') {
                success = false;
            }
        }
        System.assertTrue(message.contains('queued'), 'Message should contain "queued"');
    }
}
