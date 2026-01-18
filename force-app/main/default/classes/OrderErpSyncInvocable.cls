/**
 * @description Invocable Apex class to allow manual triggering of Order ERP sync from Flows or UI.
 * Can be called from a Flow screen or button.
 * @author Divya Sai Krishna
 * @group Integration
 * @date 2026-01-18
 */
public with sharing class OrderErpSyncInvocable {
    /**
     * @description Invocable method to sync specific Order records to ERP.
     * @param orderIds List of Order IDs to sync
     * @return Map with keys 'success' (boolean) and 'message' (string)
     */
    @InvocableMethod(label='Sync Orders to ERP' description='Enqueues a job to push selected Orders to ERP.')
    public static list<KeyValueResult> syncOrdersToErp(List<Id> orderIds) {

        KeyValueResult result = new KeyValueResult();
            result.key = 'false';
            result.value = 'No records provided.';
        List<KeyValueResult> results = new List<KeyValueResult>();
        if (orderIds == null || orderIds.isEmpty()) {
            results.add(result);
            return results;
        }

        // Enqueue a job to process these records asynchronously
        System.enqueueJob(new OrderErpSyncQueueable(orderIds));

        KeyValueResult r = new KeyValueResult();
            r.key = 'message';
            r.value = 'Queued ' + orderIds.size() + ' orders for ERP sync.';
        results.add(r);
        
        return results;
    }

    public class KeyValueResult {
        @InvocableVariable
        public String key;

        @InvocableVariable
        public String value;
    }
}
