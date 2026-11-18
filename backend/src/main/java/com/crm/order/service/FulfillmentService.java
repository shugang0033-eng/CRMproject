package com.crm.order.service;

import com.crm.common.DocCode;

import org.springframework.jdbc.core.JdbcTemplate;
import com.crm.customer.service.CustomerLifecycle;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

import static com.crm.order.service.BillingService.*;

@Service
public class FulfillmentService {
    private final JdbcTemplate db;
    private final CustomerLifecycle lifecycle;
    private final OrderWriteService access;

    public FulfillmentService(JdbcTemplate db,OrderWriteService access, CustomerLifecycle lifecycle) {
        this.db = db;
        this.lifecycle = lifecycle;
        this.access=access;
    }

    private Map<String,Object> order(Long employee,long id,String permission) {
        var grants=access.require(employee,permission);
        var row=access.one("SELECT * FROM crm_orders WHERE id=? AND deleted_at IS NULL FOR UPDATE",id);
        access.checkOwner(employee,grants,id(row,"owner_id"));
        return row;
    }

    @Transactional
    public Object ship(Long employee,long orderId,Shipment f) {
        var order=order(employee,orderId,"order.ship");
        if(!Set.of("待发货","部分发货").contains(order.get("status"))) throw error(HttpStatus.CONFLICT);
        String code=DocCode.next(db,"FH","crm_shipments");
        db.update("INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,created_by) VALUES(?,?,?,?,?,'运输中',?)",
            code,orderId,f.at()==null?LocalDate.now():f.at(),text(f.logistics()),text(f.trackingNo()),employee);
        long id=db.queryForObject("SELECT id FROM crm_shipments WHERE code=?",Long.class,code);
        BigDecimal amount=BigDecimal.ZERO;
        int boxes=0;
        for (var line:lines(f.items())) {
            var item=item(orderId,line);
            long itemId=id(item,"id");
            BigDecimal available=money(item,"qty").subtract(money(item,"shipped_qty"));
            if(available.compareTo(line.qty())<0) throw error(HttpStatus.BAD_REQUEST);
            BigDecimal units=stockUnits(item,line);
            if(db.update("UPDATE crm_product_inventory SET available=available-? WHERE product_id=? AND available>=?",
                units,line.productId(),units)==0) throw error(HttpStatus.CONFLICT);
            db.update("UPDATE crm_order_items SET shipped_qty=shipped_qty+? WHERE id=?",line.qty(),itemId);
            db.update("INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty) VALUES(?,?,?,?,?)",
                id,itemId,line.productId(),line.unit(),line.qty());
            amount=amount.add(money(item,"price").multiply(line.qty()).setScale(2,java.math.RoundingMode.HALF_UP));
            if("箱".equals(line.unit())) boxes+=line.qty().intValue();
        }
        db.update("UPDATE crm_shipments SET amount=?,boxes=? WHERE id=?",amount,boxes,id);
        db.update("UPDATE crm_orders SET status='部分发货' WHERE id=?",orderId);
        return Map.of("id",id,"code",code,"amount",amount,"status","运输中");
    }

    @Transactional
    public void sign(Long employee,long shipmentId) {
        long orderId=db.queryForObject("SELECT order_id FROM crm_shipments WHERE id=?",Long.class,shipmentId);
        order(employee,orderId,"order.ship");
        if(db.update("UPDATE crm_shipments SET status='已签收',signed_at=NOW() WHERE id=? AND status IN ('运输中','已发货')",
            shipmentId)==0) throw error(HttpStatus.CONFLICT);
        db.update("""
            UPDATE crm_orders SET status='已签收' WHERE id=?
              AND NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=? AND shipped_qty<qty)
              AND NOT EXISTS(SELECT 1 FROM crm_shipments WHERE order_id=? AND status<>'已签收')
            """,orderId,orderId,orderId);
        lifecycle.refresh(db.queryForObject("SELECT customer_id FROM crm_orders WHERE id=?",Long.class,orderId));
    }

    @Transactional
    public Object requestReturn(Long employee,ReturnForm f) {
        var order=order(employee,f.orderId(),"order.return");
        state(order,"已签收");
        if(!Set.of("质量问题","发错规格","客户取消","运输破损","其他").contains(f.reason())) throw error(HttpStatus.BAD_REQUEST);
        String code=DocCode.next(db,"RT","crm_returns");
        db.update("INSERT INTO crm_returns(code,order_id,customer_id,return_date,reason,note,created_by) VALUES(?,?,?,CURDATE(),?,?,?)",
            code,f.orderId(),order.get("customer_id"),f.reason(),text(f.note()),employee);
        long id=db.queryForObject("SELECT id FROM crm_returns WHERE code=?",Long.class,code);
        BigDecimal total=BigDecimal.ZERO;
        for(var line:lines(f.items())) {
            var item=item(f.orderId(),line);
            long itemId=id(item,"id");
            BigDecimal reserved=db.queryForObject("""
                SELECT COALESCE(SUM(i.qty),0) FROM crm_return_items i JOIN crm_returns r ON r.id=i.return_id
                WHERE i.order_item_id=? AND r.status='待审核'
                """,BigDecimal.class,itemId);
            if(money(item,"shipped_qty").subtract(money(item,"returned_qty")).subtract(reserved).compareTo(line.qty())<0)
                throw error(HttpStatus.BAD_REQUEST);
            BigDecimal amount=money(item,"price").multiply(line.qty()).setScale(2,java.math.RoundingMode.HALF_UP);
            db.update("INSERT INTO crm_return_items(return_id,order_item_id,product_id,unit,qty,price,amount) VALUES(?,?,?,?,?,?,?)",
                id,itemId,line.productId(),line.unit(),line.qty(),item.get("price"),amount);
            total=total.add(amount);
        }
        db.update("UPDATE crm_returns SET amount=? WHERE id=?",total,id);
        return Map.of("id",id,"code",code,"amount",total,"status","待审核");
    }

    @Transactional
    public void confirmReturn(Long employee,long id,String result,boolean restock,String reason) {
        long orderId=db.queryForObject("SELECT order_id FROM crm_returns WHERE id=?",Long.class,id);
        order(employee,orderId,"order.approve");
        state(access.one("SELECT status FROM crm_returns WHERE id=? FOR UPDATE",id),"待审核");
        if("reject".equals(result)) {
            db.update("UPDATE crm_returns SET status='已驳回',reject_reason=?,confirmed_by=?,confirmed_at=NOW() WHERE id=?",reason,employee,id);
            return;
        }
        if(!"pass".equals(result)) throw error(HttpStatus.BAD_REQUEST);
        for(var item:db.queryForList("""
            SELECT r.*,o.unit_factor FROM crm_return_items r JOIN crm_order_items o ON o.id=r.order_item_id
            WHERE r.return_id=? ORDER BY r.product_id,r.id
            """,id)) {
            db.update("UPDATE crm_order_items SET returned_qty=returned_qty+? WHERE id=?",item.get("qty"),item.get("order_item_id"));
            if(restock) {
                var line=new Line(id(item,"product_id"),(String)item.get("unit"),money(item,"qty"));
                db.update("""
                    INSERT INTO crm_product_inventory(product_id,available) VALUES(?,?)
                    ON DUPLICATE KEY UPDATE available=available+VALUES(available)
                    """,line.productId(),stockUnits(item,line));
            }
        }
        db.update("UPDATE crm_returns SET status=?,confirmed_at=NOW(),confirmed_by=? WHERE id=?",restock?"已入库":"已退款",employee,id);
        db.update("""
            UPDATE crm_orders SET status='已退货' WHERE id=?
             AND NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=? AND shipped_qty>returned_qty)
            """,orderId,orderId);
        lifecycle.refresh(db.queryForObject("SELECT customer_id FROM crm_orders WHERE id=?",Long.class,orderId));
    }

    @Transactional
    public Object tracking(Long employee,long id) {
        var row=access.one("SELECT order_id,logistics AS company,tracking_no AS trackingNo,status FROM crm_shipments WHERE id=?",id);
        order(employee,id(row,"order_id"),"order.view");
        row.remove("order_id");
        row.put("traces",List.of());
        return row;
    }

    private Map<String,Object> item(long order,Line line) {
        return access.one("SELECT * FROM crm_order_items WHERE order_id=? AND product_id=? AND unit=?",
            order,line.productId(),line.unit());
    }

    private BigDecimal stockUnits(Map<String,Object> item,Line line) {
        Number factor=(Number)item.get("unit_factor");
        if(factor==null) factor=(Number)access.one("SELECT factor FROM crm_product_units WHERE product_id=? AND unit_name=?",
            line.productId(),line.unit()).get("factor");
        return line.qty().multiply(BigDecimal.valueOf(factor.longValue()));
    }

    private List<Line> lines(List<Line> rows) {
        if(rows==null || rows.isEmpty()) throw error(HttpStatus.BAD_REQUEST);
        var seen=new HashSet<String>();
        for(var row:rows) {
            positive(row.qty());
            if(!seen.add(row.productId()+":"+row.unit())) throw error(HttpStatus.BAD_REQUEST);
        }
        return rows.stream().sorted(Comparator.comparingLong(Line::productId)).toList();
    }

    public record Line(long productId,String unit,BigDecimal qty) {}
    public record Shipment(List<Line> items,String logistics,String trackingNo,LocalDate at) {}
    public record ReturnForm(long orderId,String reason,String note,List<Line> items) {}
}



