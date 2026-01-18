# Order to ERP Integration

This module implements an integration between Salesforce Orders and an external ERP system. It follows Salesforce best practices for Apex development, including:

- One Trigger Per Object pattern
- Trigger Handler with bulkification
- Queueable for async processing
- Named Credential for secure API calls
- Comprehensive logging to `Integration_Log__c`
- Unit tests with 75%+ coverage
- Invocable Apex for manual flow triggering

## Components

### Trigger
- `OrderTrigger.trigger`: Delegates to `OrderTriggerHandler` after insert/update

### Handler
- `OrderTriggerHandler.cls`: Filters records requiring sync and enqueues jobs

### Queueable Job
- `OrderErpSyncQueueable.cls`: Performs actual data querying, payload building, API callout, and logging

### Supporting Classes
- `OrderPayloadBuilder.cls`: Transforms Order + OrderItems into JSON payload
- `ErpHttpService.cls`: Encapsulates HTTP callout logic
- `IntegrationLogger.cls`: Handles logging to `Integration_Log__c`

### Optional Features
- `OrderErpSyncInvocable.cls`: Allows manual triggering from Flows/UI

## Setup Instructions

1. **Create Named Credential**
   - Go to Setup → Named Credentials
   - Create a new Named Credential named `ERP_NC`
   - Configure authentication (OAuth, Basic Auth, etc.)
   - Set base URL to your ERP endpoint (e.g., `https://erp.example.com/api`)

2. **Deploy Metadata**
   - Deploy all Apex classes and triggers
   - Ensure `Integration_Log__c` custom object exists with required fields

3. **Permissions**
   - Grant appropriate permissions to users who need to trigger sync manually
   - Ensure API callout permissions are enabled

## How It Works

1. When an Order is inserted or updated, the trigger fires
2. The handler filters records based on business rules (insert or status/amount change)
3. For each qualifying record, a Queueable job is enqueued
4. The Queueable:
   - Queries the Order and related OrderItems
   - Builds a JSON payload
   - Makes a POST callout to ERP endpoint
   - Logs the outcome to `Integration_Log__c`

## Testing

Run the unit tests in `OrderErpSyncTest.cls`. They cover:
- Trigger handler logic
- Payload building
- Queueable execution (simulated callout failure)
- Logger functionality
- Invocable method

## Logging

All interactions are logged to `Integration_Log__c` with:
- Correlation ID for tracing
- Request/Response payloads
- Status and severity
- Error codes and messages
- Timestamps and direction (inbound/outbound)
