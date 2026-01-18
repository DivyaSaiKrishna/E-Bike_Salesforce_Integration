/**
 * @description Logging utility for Integration_Log__c with bulk support and USER_MODE DML.
 * Follows standards: Database methods, USER_MODE, enums for constants, return-early, no debug in prod.
 * Requires custom object Integration_Log__c and fields present in the org (already in repo).
 * @author divya sai krishna
 * @group Integration
 * @date 2026-01-18
 */
public with sharing class IntegrationLogger {
    public enum Severity { INFO, WARN, ERROR }
    public enum Status { REQUESTED, SUCCESS, FAILED }

    public class LogEntry {
        public String correlationId;
        public String endpoint;
        public String method;
        public String direction;
        public String sourceSystem;
        public String targetSystem;
        public Severity severity;
        public Status status;
        public String requestPayload;
        public String responsePayload;
        public String errorCode;
        public String errorMessage;
        public String stackTrace;
        public Integer retryCount;
        public Datetime nextRetryAt;
        public Datetime occurredOn;
    }

    private List<Integration_Log__c> buffer = new List<Integration_Log__c>();

    public static String newCorrelationId() {
        return String.valueOf(System.UUID.randomUUID());
    }

    public void add(LogEntry e) {
        if (e == null) return;
        Integration_Log__c log = new Integration_Log__c();
        log.Correlation_Id__c = e.correlationId;
        log.Endpoint__c = e.endpoint;
        log.Method__c = e.method;
        log.Direction__c = e.direction;
        log.Source_System__c = e.sourceSystem;
        log.Target_System__c = e.targetSystem;
        log.Severity__c = (e.severity == null) ? String.valueOf(Severity.INFO) : String.valueOf(e.severity);
        log.Status__c = (e.status == null) ? String.valueOf(Status.REQUESTED) : String.valueOf(e.status);
        log.Request_Payload__c = e.requestPayload;
        log.Response_Payload__c = e.responsePayload;
        log.Error_Code__c = e.errorCode;
        log.Error_Message__c = e.errorMessage;
        log.Stack_Trace__c = e.stackTrace;
        log.Retry_Count__c = (e.retryCount == null) ? 0 : e.retryCount;
        log.Next_Retry_At__c = e.nextRetryAt;
        log.Occurred_On__c = (e.occurredOn == null) ? System.now() : e.occurredOn;
        buffer.add(log);
    }

    public void flush() {
        if (buffer.isEmpty()) return;
        Database.SaveResult[] results = Database.insert(buffer, false, AccessLevel.USER_MODE);
        
        buffer.clear();
    }
}
