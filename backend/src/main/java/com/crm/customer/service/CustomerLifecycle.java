package com.crm.customer.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CustomerLifecycle {
    private final JdbcTemplate db;

    public CustomerLifecycle(JdbcTemplate db) {
        this.db = db;
    }

    public void refresh(Long customerId) {
        db.update("""
            UPDATE crm_customers c JOIN (
              SELECT id,lastOrderAt,CASE WHEN NOT hasDeal THEN '跟进中'
                WHEN overdue>0 THEN '待回款'
                WHEN DATEDIFF(CURDATE(),lastOrderAt)>90 THEN '流失风险' ELSE '合作中' END AS next_status
              FROM crm_customer_trade WHERE (? IS NULL OR id=?)
            ) t ON t.id=c.id
            SET c.status_at=IF(c.status<>t.next_status OR c.status_at IS NULL,NOW(),c.status_at),
                c.status=t.next_status,c.last_order_at=t.lastOrderAt
            WHERE c.merged_into_id IS NULL
            """,customerId,customerId);
    }

    @org.springframework.context.event.EventListener(org.springframework.boot.context.event.ApplicationReadyEvent.class)
    public void backfill() { refresh(null); }

    @Scheduled(cron = "0 30 2 * * *", zone = "Asia/Shanghai")
    @Transactional
    public void recycle() {
        refresh(null);
        var ids = db.queryForList("""
            SELECT c.id FROM crm_customers c JOIN crm_customer_trade t ON t.id=c.id
            WHERE c.owner_id IS NOT NULL AND c.merged_into_id IS NULL AND NOT t.hasDeal
              AND c.status NOT IN ('合作中','待回款')
              AND GREATEST(COALESCE(c.last_follow_at,c.created_at),c.created_at,
                COALESCE((SELECT MAX(created_at) FROM crm_customer_transfers WHERE customer_id=c.id),c.created_at))
                < NOW()-INTERVAL 30 DAY
            ORDER BY c.id FOR UPDATE
            """,Long.class);
        for (long id : ids) {
            db.update("""
                INSERT INTO crm_customer_transfers(customer_id,previous_owner_id,reason)
                SELECT id,owner_id,'超过 30 天未跟进' FROM crm_customers WHERE id=?
                """,id);
            db.update("""
                UPDATE crm_customers SET owner_id=NULL,pool_entered_at=NOW(),pool_reason='超过 30 天未跟进' WHERE id=?
                """,id);
        }
    }
}

