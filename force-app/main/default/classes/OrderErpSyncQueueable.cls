/**
 * @description Queueable job to push Orders to external ERP via HTTP POST using Named Credential 'ERP_NC'.
 * Builds payloads, performs callouts, and logs outcomes to Integration_Log__c.
 * Applies bulk processing, security enforcement, and error handling.
 * Note: Configure Named Credential 'ERP_NC' in the org to point to the ERP base URL.
 * Endpoint path used: /orders
 * Direction: Outbound
 * Method: POST
 * @author Divya Sai Krishna
 * @group Integration
 * @date 2026-01-18
 */
public with sharing class OrderErpSyncQueueable implements Queueable, Database.AllowsCallouts {

    private static final String NAMED_CREDENTIAL = 'ERP_NC';

    // Nested helper classes must live in their own .cls files in Apex.
    // Move OrderPayloadBuilder, ErpHttpService, and IntegrationLogger to separate classes.
    private static final String ORDERS_PATH = '/orders';
    private static final String METHOD_POST = 'POST';
    private static final String TARGET_SYSTEM = 'ERP';
    private static final String SOURCE_SYSTEM = 'Salesforce';
    private static final String DIRECTION = 'Outbound';

    private final List<Id> orderIds;

    public OrderErpSyncQueueable(List<Id> orderIds) {
        this.orderIds = (orderIds == null) ? new List<Id>() : new List<Id>(orderIds);
    }

    public void execute(QueueableContext qc) {
        if (orderIds.isEmpty()) {
            return;
        }

        // 1) Query Orders + OrderItems in bulk (single SOQL per object) with security enforcement
        Map<Id, Order> ordersById = new Map<Id, Order>([
            SELECT Id, OrderNumber, AccountId, Status, EffectiveDate, TotalAmount, LastModifiedDate
            FROM Order
            WHERE Id IN :orderIds
            WITH SECURITY_ENFORCED
        ]);

        if (ordersById.isEmpty()) {
            return;
        }

        List<OrderItem> items = [
            SELECT Id, OrderId, Product2Id, Quantity, UnitPrice, TotalPrice
            FROM OrderItem
            WHERE OrderId IN :ordersById.keySet()
            WITH SECURITY_ENFORCED
        ];

        Map<Id, List<OrderItem>> itemsByOrder = new Map<Id, List<OrderItem>>();
        for (OrderItem oi : items) {
            List<OrderItem> bucket = itemsByOrder.get(oi.OrderId);
            if (bucket == null) {
                bucket = new List<OrderItem>();
                itemsByOrder.put(oi.OrderId, bucket);
            }
            bucket.add(oi);
        }

        // 2) Build payload DTOs
        List<OrderPayloadBuilder.OrderDTO> dtos = new List<OrderPayloadBuilder.OrderDTO>();
        for (Order o : ordersById.values()) {
            List<OrderItem> related = itemsByOrder.get(o.Id);
            dtos.add(OrderPayloadBuilder.buildOrderDTO(o, related));
        }

        // 3) Serialize payload (batch)
        String requestPayload = JSON.serialize(dtos);

        // 4) Perform callout
        String correlationId = IntegrationLogger.newCorrelationId();
        IntegrationLogger.LogEntry log = new IntegrationLogger.LogEntry();
        log.correlationId = correlationId;
        log.endpoint = '/services/apexrest' + ORDERS_PATH; 
        log.method = METHOD_POST;
        log.direction = DIRECTION;
        log.sourceSystem = SOURCE_SYSTEM;
        log.targetSystem = TARGET_SYSTEM;
        log.severity = IntegrationLogger.Severity.INFO;
        log.status = IntegrationLogger.Status.REQUESTED;
        log.requestPayload = requestPayload;

        IntegrationLogger buffer = new IntegrationLogger();

        try {
            HttpResponse resp = ErpHttpService.postJson(NAMED_CREDENTIAL, ORDERS_PATH, requestPayload, correlationId);

            Integer statusCode = resp.getStatusCode();
            String responseBody = resp.getBody();

            if (statusCode >= 200 && statusCode < 300) {
                log.status = IntegrationLogger.Status.SUCCESS;
                log.responsePayload = responseBody;
                buffer.add(log);
            } else {
                // Non-2xx => failure
                log.status = IntegrationLogger.Status.FAILED;
                log.severity = IntegrationLogger.Severity.ERROR;
                log.responsePayload = responseBody;
                log.errorCode = String.valueOf(statusCode);
                buffer.add(log);
            }
        } catch (Exception ex) {
            log.status = IntegrationLogger.Status.FAILED;
            log.severity = IntegrationLogger.Severity.ERROR;
            log.errorCode = ex.getTypeName();
            log.errorMessage = ex.getMessage();
            log.stackTrace = ex.getStackTraceString();
            buffer.add(log);
        } finally {
            // 5) Persist logs in USER_MODE
            buffer.flush();
        }
    }
}
