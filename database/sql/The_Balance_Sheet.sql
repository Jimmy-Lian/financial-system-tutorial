-- =================================================================
-- 附录A：完整财务报表存储过程脚本 (新资产负-债表格式)
-- =================================================================
-- 说明：
-- 1. 本脚本将重构 balance_sheet_report 表以支持左右栏对称格式。
-- 2. proc_generate_balance_sheet 存储过程将被完全重写，以匹配标准报表格式。
-- 3. 其他存储过程和结果表保持不变。
-- =================================================================

-- 使用目标数据库
USE financial_db;

-- ----------------------------
-- 1. 重建资产负-债表结果表
-- ----------------------------
DROP TABLE IF EXISTS `balance_sheet_report`;
CREATE TABLE `balance_sheet_report` (
  `id` int NOT NULL AUTO_INCREMENT,
  `line_index` int DEFAULT NULL COMMENT '行次 (用于排序)',
  `asset_item` varchar(100) DEFAULT NULL COMMENT '资产项目',
  `asset_opening` decimal(14,2) DEFAULT NULL COMMENT '资产期初数',
  `asset_closing` decimal(14,2) DEFAULT NULL COMMENT '资产期末数',
  `liability_equity_item` varchar(100) DEFAULT NULL COMMENT '负-债及所有者权益项目',
  `liability_equity_opening` decimal(14,2) DEFAULT NULL COMMENT '负-债和权益期初数',
  `liability_equity_closing` decimal(14,2) DEFAULT NULL COMMENT '负-债和权益期末数',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产负-债表结果表(新格式)';


-- ----------------------------
-- 2. 重写生成资产负-债表的存储过程 (完整版)
-- ----------------------------
DROP PROCEDURE IF EXISTS `proc_generate_balance_sheet`;

DELIMITER $$
CREATE PROCEDURE `proc_generate_balance_sheet`(IN fiscal_year_param INT)
BEGIN
    -- 声明变量
    DECLARE prev_year INT;
    DECLARE var_opening, var_closing DECIMAL(14,2);
    SET prev_year = fiscal_year_param - 1;

    -- 开始前清空历史数据
    TRUNCATE TABLE `balance_sheet_report`;

    -- 使用临时表来准备左右两栏的数据
    DROP TEMPORARY TABLE IF EXISTS temp_assets;
    CREATE TEMPORARY TABLE temp_assets (
        line_index INT,
        item VARCHAR(100),
        opening DECIMAL(14,2),
        closing DECIMAL(14,2)
    );

    DROP TEMPORARY TABLE IF EXISTS temp_liabilities_equity;
    CREATE TEMPORARY TABLE temp_liabilities_equity (
        line_index INT,
        item VARCHAR(100),
        opening DECIMAL(14,2),
        closing DECIMAL(14,2)
    );

    -- ==================== 填充资产部分到临时表 ====================
    -- 货币资金
    INSERT INTO temp_assets (line_index, item, opening, closing)
    SELECT 1, '  货币资金', 
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code IN ('1001', '1002')),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code IN ('1001', '1002'));
    -- 应收票据
    INSERT INTO temp_assets (line_index, item, opening, closing)
    SELECT 2, '  应收票据', 
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code = '1121'),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code = '1121');
    -- 应收账款
    INSERT INTO temp_assets (line_index, item, opening, closing)
    SELECT 3, '  应收账款', 
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code = '1122'),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code = '1122');
    -- 存货
    INSERT INTO temp_assets (line_index, item, opening, closing)
    SELECT 4, '  存货', 
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND (account_code LIKE '1401%' OR account_code LIKE '1402%' OR account_code LIKE '1403%' OR account_code LIKE '1405%')),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND (account_code LIKE '1401%' OR account_code LIKE '1402%' OR account_code LIKE '1403%' OR account_code LIKE '1405%'));
    
    -- 流动资产合计
    SELECT SUM(opening), SUM(closing) INTO var_opening, var_closing FROM temp_assets WHERE line_index < 15;
    INSERT INTO temp_assets (line_index, item, opening, closing) VALUES (15, '流动资产合计', var_opening, var_closing);

    -- 固定资产净额
    INSERT INTO temp_assets (line_index, item, opening, closing)
    SELECT 16, '  固定资产', 
        (SELECT COALESCE(SUM(CASE WHEN coa.balance_direction = 'debit' THEN ab.closing_balance ELSE -ab.closing_balance END), 0) FROM account_balances ab JOIN chart_of_accounts coa ON ab.account_code = coa.account_code WHERE ab.fiscal_year = prev_year AND ab.account_code IN ('1601', '1602')),
        (SELECT COALESCE(SUM(CASE WHEN coa.balance_direction = 'debit' THEN ab.closing_balance ELSE -ab.closing_balance END), 0) FROM account_balances ab JOIN chart_of_accounts coa ON ab.account_code = coa.account_code WHERE ab.fiscal_year = fiscal_year_param AND ab.account_code IN ('1601', '1602'));
    -- 无形资产净额
    INSERT INTO temp_assets (line_index, item, opening, closing)
    SELECT 17, '  无形资产', 
        (SELECT COALESCE(SUM(CASE WHEN coa.balance_direction = 'debit' THEN ab.closing_balance ELSE -ab.closing_balance END), 0) FROM account_balances ab JOIN chart_of_accounts coa ON ab.account_code = coa.account_code WHERE ab.fiscal_year = prev_year AND ab.account_code IN ('1701', '1702')),
        (SELECT COALESCE(SUM(CASE WHEN coa.balance_direction = 'debit' THEN ab.closing_balance ELSE -ab.closing_balance END), 0) FROM account_balances ab JOIN chart_of_accounts coa ON ab.account_code = coa.account_code WHERE ab.fiscal_year = fiscal_year_param AND ab.account_code IN ('1701', '1702'));

    -- 非流动资产合计
    SELECT SUM(opening), SUM(closing) INTO var_opening, var_closing FROM temp_assets WHERE line_index > 15 AND line_index < 29;
    INSERT INTO temp_assets (line_index, item, opening, closing) VALUES (29, '非流动资产合计', var_opening, var_closing);

    -- 资产总计
    SELECT SUM(opening), SUM(closing) INTO var_opening, var_closing FROM temp_assets WHERE line_index IN (15, 29);
    INSERT INTO temp_assets (line_index, item, opening, closing) VALUES (30, '资产总计', var_opening, var_closing);

    -- ==================== 填充负-债和权益部分到临时表 ====================
    -- 短期借款
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing)
    SELECT 31, '  短期借款',
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code = '2001'),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code = '2001');
    -- 应付账款
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing)
    SELECT 32, '  应付账款',
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code = '2202'),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code = '2202');

    -- 流动负-债合计
    SELECT SUM(opening), SUM(closing) INTO var_opening, var_closing FROM temp_liabilities_equity WHERE line_index < 44;
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing) VALUES (44, '流动负-债合计', var_opening, var_closing);
    
    -- 负-债合计
    SELECT SUM(opening), SUM(closing) INTO var_opening, var_closing FROM temp_liabilities_equity WHERE line_index IN (44); -- 假设只有流动负-债
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing) VALUES (52, '负-债合计', var_opening, var_closing);

    -- 实收资本
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing)
    SELECT 53, '实收资本',
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code = '4001'),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code = '4001');
    -- 资本公积
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing)
    SELECT 54, '资本公积',
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code = '4002'),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code = '4002');
    -- 盈余公积
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing)
    SELECT 55, '盈余公积',
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND account_code = '4101'),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND account_code = '4101');
    -- 未分配利润
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing)
    SELECT 56, '未分配利润',
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = prev_year AND (account_code = '4103' OR account_code = '4104')),
        (SELECT COALESCE(SUM(closing_balance), 0) FROM account_balances WHERE fiscal_year = fiscal_year_param AND (account_code = '4103' OR account_code = '4104'));

    -- 所有者权益合计
    SELECT SUM(opening), SUM(closing) INTO var_opening, var_closing FROM temp_liabilities_equity WHERE line_index >= 53 AND line_index < 58;
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing) VALUES (58, '所有者权益合计', var_opening, var_closing);

    -- 负-债和所有者权益总计
    SELECT SUM(opening), SUM(closing) INTO var_opening, var_closing FROM temp_liabilities_equity WHERE line_index IN (52, 58);
    INSERT INTO temp_liabilities_equity (line_index, item, opening, closing) VALUES (59, '负-债和所有者权益总计', var_opening, var_closing);

    -- ==================== 将两个临时表合并到最终结果表 (最终修正版) ====================
    -- 使用两步INSERT来模拟FULL OUTER JOIN，避免 "Can't reopen table" 错误

    -- 第一步：插入所有资产项，以及与之匹配的负债和权益项 (LEFT JOIN)
    INSERT INTO balance_sheet_report (line_index, asset_item, asset_opening, asset_closing, liability_equity_item, liability_equity_opening, liability_equity_closing)
    SELECT
        a.line_index,
        a.item,
        a.opening,
        a.closing,
        l.item,
        l.opening,
        l.closing
    FROM
        temp_assets a
    LEFT JOIN
        temp_liabilities_equity l ON a.line_index = l.line_index - 30; -- 行次对齐

    -- 第二步：插入所有在资产部分没有匹配到的负债和权益项
    INSERT INTO balance_sheet_report (line_index, liability_equity_item, liability_equity_opening, liability_equity_closing)
    SELECT
        l.line_index,
        l.item,
        l.opening,
        l.closing
    FROM
        temp_liabilities_equity l
    WHERE NOT EXISTS (SELECT 1 FROM balance_sheet_report b WHERE b.line_index = l.line_index);


    -- 清理临时表
    DROP TEMPORARY TABLE temp_assets;
    DROP TEMPORARY TABLE temp_liabilities_equity;

END$$
DELIMITER ;


