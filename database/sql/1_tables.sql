-- 临时禁用外键检查
SET FOREIGN_KEY_CHECKS = 0;

-- 确保在 financial_db 数据库下执行
USE financial_db;
-- ----------------------------
-- Table structure for chart_of_accounts 
-- ----------------------------
DROP TABLE IF EXISTS `chart_of_accounts`;
CREATE TABLE `chart_of_accounts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `account_code` varchar(16) NOT NULL COMMENT '科目代码',
  `account_name` varchar(100) NOT NULL COMMENT '科目名称',
  `parent_code` varchar(16) DEFAULT NULL COMMENT '上级科目代码',
  `level` tinyint NOT NULL COMMENT '科目级别',
  `balance_direction` enum('debit','credit') NOT NULL COMMENT '余额方向',
  `is_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_code` (`account_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='会计科目定义表';

-- ----------------------------
-- Table structure for account_balances 
-- ----------------------------
DROP TABLE IF EXISTS `account_balances`;
CREATE TABLE `account_balances` (
  `id` int NOT NULL AUTO_INCREMENT,
  `account_code` varchar(16) NOT NULL COMMENT '科目代码',
  `fiscal_year` int NOT NULL COMMENT '会计年度',
  `opening_balance` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '本年期初余额',
  `period_debit` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '本期借方发生额',
  `period_credit` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '本期贷方发生额',
  `closing_balance` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '期末余额',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_year` (`account_code`,`fiscal_year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='科目余额表';

-- ----------------------------
-- Table structure for vouchers 
-- ----------------------------
DROP TABLE IF EXISTS `vouchers`;
CREATE TABLE `vouchers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `voucher_date` date NOT NULL COMMENT '凭证日期',
  `voucher_type` varchar(10) NOT NULL COMMENT '凭证字',
  `voucher_number` int NOT NULL COMMENT '凭证号',
  `summary` varchar(255) NOT NULL COMMENT '摘要',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='凭证主表';

-- ----------------------------
-- Table structure for journal_entries
-- ----------------------------
DROP TABLE IF EXISTS `journal_entries`;
CREATE TABLE `journal_entries` (
  `id` int NOT NULL AUTO_INCREMENT,
  `voucher_id` int NOT NULL COMMENT '凭证ID',
  `account_code` varchar(16) NOT NULL COMMENT '科目代码',
  `summary` varchar(255) NOT NULL COMMENT '摘要',
  `debit_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '借方金额',
  `credit_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '贷方金额',
  PRIMARY KEY (`id`),
  KEY `idx_voucher_id` (`voucher_id`),
  KEY `idx_account_code` (`account_code`),
  CONSTRAINT `fk_entry_voucher` FOREIGN KEY (`voucher_id`) REFERENCES `vouchers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='凭证分录表';

-- 重新启用外键检查

SET FOREIGN_KEY_CHECKS = 1;
