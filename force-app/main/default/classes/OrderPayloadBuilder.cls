/**
 * @description Shapes Order + OrderItems into a serializable DTO for ERP.
 * Uses simple DTO classes to control JSON structure.
 * Security: Data provided by caller; no SOQL here.
 * @author Divya Sai Krishna
 * @group Integration
 * @date 2026-01-18
 */
public with sharing class OrderPayloadBuilder {
    public class OrderItemDTO {
        public String productId;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal totalPrice;
    }

    public class OrderDTO {
        public String id;
        public String orderNumber;
        public String accountId;
        public String status;
        public Date effectiveDate;
        public Decimal totalAmount;
        public Datetime lastModifiedDate;
        public List<OrderItemDTO> items;
    }

    /**
     * @description Build an OrderDTO from Order + OrderItems already queried by caller.
     * @param o Order record
     * @param items Related OrderItem list
     */
    public static OrderDTO buildOrderDTO(Order o, List<OrderItem> items) {
        OrderDTO dto = new OrderDTO();
        dto.id = (o.Id == null) ? null : String.valueOf(o.Id);
        dto.orderNumber = o.OrderNumber;
        dto.accountId = (o.AccountId == null) ? null : String.valueOf(o.AccountId);
        dto.status = o.Status;
        dto.effectiveDate = o.EffectiveDate;
        dto.totalAmount = o.TotalAmount;
        dto.lastModifiedDate = o.LastModifiedDate;

        dto.items = new List<OrderItemDTO>();
        if (items != null) {
            for (OrderItem oi : items) {
                OrderItemDTO line = new OrderItemDTO();
                line.productId = (oi.Product2Id == null) ? null : String.valueOf(oi.Product2Id);
                line.quantity = oi.Quantity;
                line.unitPrice = oi.UnitPrice;
                line.totalPrice = oi.TotalPrice;
                dto.items.add(line);
            }
        }
        return dto;
    }
}
