USE crm;
ALTER TABLE crm_lead_owner_history MODIFY action ENUM('assign', 'claim', 'return', 'transfer') NOT NULL;
