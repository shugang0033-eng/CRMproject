USE crm;
CREATE TABLE IF NOT EXISTS crm_doc_sequences (
 prefix VARCHAR(8) NOT NULL, year SMALLINT NOT NULL, serial BIGINT NOT NULL,
 PRIMARY KEY(prefix,year)
) ENGINE=InnoDB;
