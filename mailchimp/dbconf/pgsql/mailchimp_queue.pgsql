Database  mailchimp_queue  mailchimp_queue.txt   __SQLDSN__
Database  mailchimp_queue  COLUMN_DEF  "code=SERIAL PRIMARY KEY"
Database  mailchimp_queue  COLUMN_DEF  "method=VARCHAR(255) NOT NULL"
Database  mailchimp_queue  COLUMN_DEF  "opt=TEXT NOT NULL"
Database  mailchimp_queue  COLUMN_DEF  "type=VARCHAR(32) NOT NULL DEFAULT 'mailchimp'"
Database  mailchimp_queue  COLUMN_DEF  "processed=INT NOT NULL DEFAULT 0"
Database  mailchimp_queue  COLUMN_DEF  "last_modified=TIMESTAMP"
Database  mailchimp_queue  CREATE_EMPTY_TXT  1
Database  mailchimp_queue  NAME        code method opt type processed last_modified
#NoImport mailchimp_queue
