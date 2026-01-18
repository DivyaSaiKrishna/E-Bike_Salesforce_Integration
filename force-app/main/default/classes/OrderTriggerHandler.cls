/**
 * @description Handler for OrderTrigger. Bulkified and delegates async processing.
 * @author Divya Sai Krishna
 * @group Integration
 * @date 2026-01-18
 */
public with sharing class OrderTriggerHandler {
    /**
     * @description Handle after insert/update events for Order.
     * Uses Return Early pattern and bulk processing.
     * @param newList Trigger.new
     * @param oldMap Trigger.oldMap (may be null on insert)
     * @param isInsert Trigger.isInsert
     * @param isUpdate Trigger.isUpdate
     */
    public static void handleAfter(List<Order> newList, Map<Id, Order> oldMap, Boolean isInsert, Boolean isUpdate) {
        if ((newList == null) || newList.isEmpty()) {
            return;
        }

        // Filter records that require sync based on business rules
        // Default: on insert OR status/total amount changed on update
        Set<Id> toSyncIds = new Set<Id>();
        for (Order order : newList) {
            if (isInsert == true) {
                toSyncIds.add(order.Id);
                continue;
            }
            if (isUpdate == true && oldMap != null) {
                Order oldRec = oldMap.get(order.Id);
                if (oldRec == null) {
                    continue;
                }
                if (order.Status != oldRec.Status || order.TotalAmount != oldRec.TotalAmount) {
                    toSyncIds.add(order.Id);
                }
            }
        }
        if (toSyncIds.isEmpty()) {
            return;
        }

        /* Chunk the Ids to respect heap/callout limits in downstream processing
        List<List<Id>> chunks = chunkIds(new List<Id>(toSyncIds), 100);
        for (List<Id> batchIds : chunks) {
            System.enqueueJob(new OrderErpSyncQueueable(batchIds));
        }*/
    }

    private static List<List<Id>> chunkIds(List<Id> ids, Integer size) {
        List<List<Id>> result = new List<List<Id>>();

        if (ids == null || ids.isEmpty() || size == null || size <= 0) {
            return result;
        }

        List<Id> currentChunk = new List<Id>();

        for (Id recordId : ids) {
            currentChunk.add(recordId);

            if (currentChunk.size() == size) {
                result.add(currentChunk);
                currentChunk = new List<Id>(); // reset
            }
        }

        // Add remaining items
        if (!currentChunk.isEmpty()) {
            result.add(currentChunk);
        }

        return result;
    }
}
