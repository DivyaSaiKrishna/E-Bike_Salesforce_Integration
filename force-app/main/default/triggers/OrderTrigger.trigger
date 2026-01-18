/**
 * OrderTrigger
 * One trigger per object. Delegates to OrderTriggerHandler.
 * Contexts: after insert, after update
 */
trigger OrderTrigger on Order (after insert, after update) {
    if (Trigger.isAfter) {
        OrderTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
    }
}
