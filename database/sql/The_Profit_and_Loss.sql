SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for income_statement_report
-- ----------------------------
DROP TABLE IF EXISTS `income_statement_report`;

-- 创建利润表结果表
CREATE TABLE `income_statement_report` (
    `id`          INT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `line_index`  INT COMMENT '行次',
    `item`        VARCHAR(100) COMMENT '项目',
    `amount`      DECIMAL(14, 2) COMMENT '本期金额',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='利润表结果表';
SET FOREIGN_KEY_CHECKS = 1;

-- 先删除旧的存储过程
DROP PROCEDURE IF EXISTS `proc_generate_income_statement`;

-- 创建利润表过程
DELIMITER $$
CREATE PROCEDURE `proc_generate_income_statement`(IN fiscal_year_param INT)
BEGIN
    -- 声明用于存放计算结果的变量
    DECLARE var_operating_profit, var_total_profit, var_net_profit DECIMAL(14, 2);

    -- 步骤1: 创建并填充一级科目发生额临时表
    -- 注意：利润表取的是本期发生额 (period_debit, period_credit)
    DROP TEMPORARY TABLE IF EXISTS `level1_income_summary`;
    CREATE TEMPORARY TABLE `level1_income_summary` (
        `account_code` VARCHAR(16) PRIMARY KEY,
        `period_debit` DECIMAL(14, 2),
        `period_credit` DECIMAL(14, 2)
    );

    INSERT INTO `level1_income_summary` (account_code, period_debit, period_credit)
    SELECT
        ab.account_code,
        ab.period_debit,
        ab.period_credit
    FROM
        account_balances ab
    JOIN
        chart_of_accounts coa ON ab.account_code = coa.account_code
    WHERE
        ab.fiscal_year = fiscal_year_param
        AND coa.level = 1;

    -- 步骤2: 清空上次的报表结果
    TRUNCATE TABLE `income_statement_report`;

    -- 步骤3: 从临时表中取数，填充报表
    -- 1. 主营业务收入 (取贷方发生额)
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 1, '一、主营业务收入', COALESCE(SUM(period_credit), 0) FROM `level1_income_summary` WHERE `account_code` = '6001';

    -- 2. 减：主营业务成本 (取借方发生额)
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 2, '  减：主营业务成本', COALESCE(SUM(period_debit), 0) FROM `level1_income_summary` WHERE `account_code` = '6401';

    -- 3. 税金及附加 (取借方发生额) - 【修正】原脚本6601错误，应为6403
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 3, '       税金及附加', COALESCE(SUM(period_debit), 0) FROM `level1_income_summary` WHERE `account_code` = '6403';
    
    -- 4. 销售费用 (取借方发生额) - 【修正】原脚本6602错误，应为6601
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 6, '  减：销售费用', COALESCE(SUM(period_debit), 0) FROM `level1_income_summary` WHERE `account_code` = '6601';
    
    -- 5. 管理费用 (取借方发生额) - 【修正】原脚本6603错误，应为6602
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 7, '       管理费用', COALESCE(SUM(period_debit), 0) FROM `level1_income_summary` WHERE `account_code` = '6602';

    -- 6. 财务费用 (取借方发生额) - 【修正】原脚本6604错误，应为6603
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 8, '       财务费用', COALESCE(SUM(period_debit), 0) FROM `level1_income_summary` WHERE `account_code` = '6603';

    -- 7. 计算营业利润
    -- 营业利润 = 主营业务收入 - (主营成本 + 税金 + 销售费用 + 管理费用 + 财务费用)
    SELECT
        (SELECT amount FROM `income_statement_report` WHERE line_index = 1) - 
        COALESCE(SUM(amount), 0)
    INTO var_operating_profit
    FROM `income_statement_report`
    WHERE line_index IN (2, 3, 6, 7, 8);
    INSERT INTO `income_statement_report` (line_index, item, amount) VALUES (9, '二、营业利润（亏损以“-”号填列）', var_operating_profit);

    -- 8. 加：营业外收入 (取贷方发生额)
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 12, '  加：营业外收入', COALESCE(SUM(period_credit), 0) FROM `level1_income_summary` WHERE `account_code` = '6301';

    -- 9. 减：营业外支出 (取借方发生额) - 【修正】原脚本6701错误，应为6711
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 13, '  减：营业外支出', COALESCE(SUM(period_debit), 0) FROM `level1_income_summary` WHERE `account_code` = '6711';

    -- 10. 计算利润总额
    -- 利润总额 = 营业利润 + 营业外收入 - 营业外支出
    SET var_total_profit = var_operating_profit 
                         + (SELECT amount FROM `income_statement_report` WHERE line_index = 12) 
                         - (SELECT amount FROM `income_statement_report` WHERE line_index = 13);
    INSERT INTO `income_statement_report` (line_index, item, amount) VALUES (14, '三、利润总额（亏损总额以“-”号填列）', var_total_profit);

    -- 11. 减：所得税费用 (取借方发生额) 
    INSERT INTO `income_statement_report` (line_index, item, amount)
    SELECT 15, '  减：所得税费用', COALESCE(SUM(period_debit), 0) FROM `level1_income_summary` WHERE `account_code` = '6801';

    -- 12. 计算净利润
    -- 净利润 = 利润总额 - 所得税费用
    SET var_net_profit = var_total_profit - (SELECT amount FROM `income_statement_report` WHERE line_index = 15);
    INSERT INTO `income_statement_report` (line_index, item, amount) VALUES (16, '四、净利润（净亏损以“-”号填列）', var_net_profit);

END$$
DELIMITER ;

