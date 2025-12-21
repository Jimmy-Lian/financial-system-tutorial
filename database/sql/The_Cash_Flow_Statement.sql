-- 设置客户端连接的字符集为 utf8mb4
SET NAMES utf8mb4;
-- 禁用外键检查，以便安全地删除和重建表
SET FOREIGN_KEY_CHECKS = 0;

-- 如果存在旧表则删除，确保脚本可重复运行
DROP TABLE IF EXISTS `cash_flow_statement_report`;
-- 创建现金流量表结果表
CREATE TABLE `cash_flow_statement_report` (
    `id`                      INT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `line_index`              INT COMMENT '行次 (用于排序)',
    `item`                    VARCHAR(100) COMMENT '项目',
    `current_period_amount`   DECIMAL(14, 2) COMMENT '本期金额',
    `prior_period_amount`     DECIMAL(14, 2) COMMENT '上期金额',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='现金流量表结果表';

-- 重新启用外键检查
SET FOREIGN_KEY_CHECKS = 1;

-- 先删除旧的存储过程
DROP PROCEDURE IF EXISTS `proc_generate_cash_flow_statement`;

-- 创建完整功能的最终版本
DELIMITER $$
CREATE PROCEDURE `proc_generate_cash_flow_statement`(IN fiscal_year_param INT)
BEGIN
    -- ==================== 变量声明 ====================
    -- 经营活动变量
    DECLARE var_cash_from_sales, var_tax_refunds, var_other_inflows DECIMAL(14, 2);
    DECLARE var_cash_for_goods, var_cash_for_employees, var_cash_for_taxes, var_other_outflows DECIMAL(14, 2);
    DECLARE var_op_inflow_total, var_op_outflow_total, var_net_op_cash_flow DECIMAL(14, 2);
    DECLARE v_revenue, v_ar_change, v_preceive_change DECIMAL(14, 2);
    DECLARE v_cogs, v_inventory_change, v_ap_change, v_prepay_change DECIMAL(14, 2);
    
    -- 【新增】投资活动变量
    DECLARE var_inv_in_disposal, var_inv_out_acquisition DECIMAL(14, 2);
    DECLARE var_inv_inflow_total, var_inv_outflow_total, var_net_inv_cash_flow DECIMAL(14, 2);

    -- 【新增】筹资活动变量
    DECLARE var_fin_in_capital, var_fin_in_loans, var_fin_out_repay, var_fin_out_dividend DECIMAL(14, 2);
    DECLARE var_fin_inflow_total, var_fin_outflow_total, var_net_fin_cash_flow DECIMAL(14, 2);

    -- 【新增】期末汇总变量
    DECLARE var_total_net_increase, var_cash_begin_balance, var_cash_end_balance DECIMAL(14, 2);

    -- ========= 步骤1: 创建并填充科目汇总临时表====================
    DROP TEMPORARY TABLE IF EXISTS `level1_full_summary`;
    CREATE TEMPORARY TABLE `level1_full_summary` (
        `account_code` VARCHAR(16) PRIMARY KEY,
        `opening_balance` DECIMAL(14, 2),
        `closing_balance` DECIMAL(14, 2),
        `period_debit` DECIMAL(14, 2),
        `period_credit` DECIMAL(14, 2)
    );

    INSERT INTO `level1_full_summary` (account_code, opening_balance, closing_balance, period_debit, period_credit)
    SELECT ab.account_code, ab.opening_balance, ab.closing_balance, ab.period_debit, ab.period_credit
    FROM account_balances ab JOIN chart_of_accounts coa ON ab.account_code = coa.account_code
    WHERE ab.fiscal_year = fiscal_year_param AND coa.level = 1;

    -- ==================== 步骤2: 清空报表====================
    TRUNCATE TABLE `cash_flow_statement_report`;

    -- ==================== 步骤3: 经营活动现金流量计算====================
    -- 1. 销售商品、提供劳务收到的现金
    SELECT
        COALESCE(SUM(CASE WHEN account_code = '6001' THEN period_credit ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN account_code IN ('1122', '1121') THEN opening_balance - closing_balance ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN account_code IN ('2203', '2205') THEN closing_balance - opening_balance ELSE 0 END), 0)
    INTO v_revenue, v_ar_change, v_preceive_change
    FROM `level1_full_summary`;
    SET var_cash_from_sales = v_revenue + v_ar_change + v_preceive_change;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (2, '  销售商品、提供劳务收到的现金', var_cash_from_sales);

    -- 2. 收到的税费返还
    SET var_tax_refunds = (SELECT COALESCE(SUM(period_credit), 0) FROM `level1_full_summary` WHERE account_code = '6301');
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (3, '  收到的税费返还', var_tax_refunds);
    
    -- 3. 收到其他与经营活动有关的现金 (简化处理)
    SET var_other_inflows = 0.00;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (4, '  收到其他与经营活动有关的现金', var_other_inflows);

    -- 小计
    SET var_op_inflow_total = var_cash_from_sales + var_tax_refunds + var_other_inflows;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (5, '经营活动现金流入小计', var_op_inflow_total);

    -- 4. 购买商品、接受劳务支付的现金
    SELECT
        COALESCE(SUM(CASE WHEN account_code = '6401' THEN period_debit ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN account_code LIKE '14%' THEN closing_balance - opening_balance ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN account_code IN ('2202', '2201') THEN opening_balance - closing_balance ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN account_code = '1123' THEN closing_balance - opening_balance ELSE 0 END), 0)
    INTO v_cogs, v_inventory_change, v_ap_change, v_prepay_change
    FROM `level1_full_summary`;
    SET var_cash_for_goods = v_cogs + v_inventory_change + v_ap_change + v_prepay_change;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (6, '  购买商品、接受劳务支付的现金', var_cash_for_goods);

    -- 5. 支付给职工以及为职工支付的现金
    SET var_cash_for_employees = (SELECT COALESCE(SUM(period_debit), 0) FROM `level1_full_summary` WHERE account_code = '2211');
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (7, '  支付给职工以及为职工支付的现金', var_cash_for_employees);

    -- 6. 支付的各项税费
    SET var_cash_for_taxes = (SELECT COALESCE(SUM(period_debit), 0) FROM `level1_full_summary` WHERE account_code = '2221');
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (8, '  支付的各项税费', var_cash_for_taxes);

    -- 7. 支付其他与经营活动有关的现金 (简化：取销售费用和管理费用中的付现部分)
    -- 此处为近似计算，精确计算需分析凭证。公式=销售费用+管理费用-计提的折旧-计提的薪酬部分
    SET var_other_outflows = (SELECT COALESCE(SUM(period_debit), 0) FROM `level1_full_summary` WHERE account_code IN ('6601', '6602'));
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (9, '  支付其他与经营活动有关的现金', var_other_outflows);

    -- 小计
    SET var_op_outflow_total = var_cash_for_goods + var_cash_for_employees + var_cash_for_taxes + var_other_outflows;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (10, '经营活动现金流出小计', var_op_outflow_total);
    
    -- 净额
    SET var_net_op_cash_flow = var_op_inflow_total - var_op_outflow_total;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (11, '经营活动产生的现金流量净额', var_net_op_cash_flow);

    -- ===============步骤4: 投资活动现金流量计算 ====================
    -- 1. 收回投资收到的现金 (简化为0)
    -- 2. 取得投资收益收到的现金 (简化为0)
    -- 3. 处置固定资产、无形资产和其他长期资产收回的现金净额
    -- 公式: (固定资产+在建工程+无形资产)的减少额，即期初-期末 > 0 的部分
    SET var_inv_in_disposal = (SELECT COALESCE(SUM(opening_balance - closing_balance), 0) FROM `level1_full_summary` WHERE account_code IN ('1601', '1604', '1701') AND opening_balance > closing_balance);
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (14, '  处置固定资产等收回的现金净额', var_inv_in_disposal);
    
    SET var_inv_inflow_total = var_inv_in_disposal;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (18, '投资活动现金流入小计', var_inv_inflow_total);
    
    -- 4. 购建固定资产、无形资产和其他长期资产支付的现金
    -- 公式: (固定资产+在建工程+无形资产)的增加额，即期末-期初 > 0 的部分
    SET var_inv_out_acquisition = (SELECT COALESCE(SUM(closing_balance - opening_balance), 0) FROM `level1_full_summary` WHERE account_code IN ('1601', '1604', '1701') AND closing_balance > opening_balance);
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (19, '  购建固定资产等支付的现金', var_inv_out_acquisition);

    SET var_inv_outflow_total = var_inv_out_acquisition;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (22, '投资活动现金流出小计', var_inv_outflow_total);

    -- 净额
    SET var_net_inv_cash_flow = var_inv_inflow_total - var_inv_outflow_total;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (23, '投资活动产生的现金流量净额', var_net_inv_cash_flow);

    -- ===========步骤5: 筹资活动现金流量计算 ====================
    -- 1. 吸收投资收到的现金
    -- 公式: 实收资本、资本公积的增加额
    SET var_fin_in_capital = (SELECT COALESCE(SUM(closing_balance - opening_balance), 0) FROM `level1_full_summary` WHERE account_code IN ('4001', '4002'));
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (25, '  吸收投资收到的现金', var_fin_in_capital);

    -- 2. 取得借款收到的现金
    -- 公式: 短期借款、长期借款的增加额
    SET var_fin_in_loans = (SELECT COALESCE(SUM(closing_balance - opening_balance), 0) FROM `level1_full_summary` WHERE account_code IN ('2001', '2501') AND closing_balance > opening_balance);
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (26, '  取得借款收到的现金', var_fin_in_loans);
    
    SET var_fin_inflow_total = var_fin_in_capital + var_fin_in_loans;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (29, '筹资活动现金流入小计', var_fin_inflow_total);

    -- 3. 偿还债务支付的现金
    -- 公式: 短期借款、长期借款的减少额
    SET var_fin_out_repay = (SELECT COALESCE(SUM(opening_balance - closing_balance), 0) FROM `level1_full_summary` WHERE account_code IN ('2001', '2501') AND opening_balance > closing_balance);
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (30, '  偿还债务支付的现金', var_fin_out_repay);

    -- 4. 分配股利、利润或偿付利息支付的现金
    -- 简化公式: 取财务费用的借方发生额 + 利润分配的借方发生额
    SET var_fin_out_dividend = (SELECT COALESCE(SUM(period_debit), 0) FROM `level1_full_summary` WHERE account_code IN ('6603', '4104'));
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (31, '  分配股利、利润或偿付利息支付的现金', var_fin_out_dividend);

    SET var_fin_outflow_total = var_fin_out_repay + var_fin_out_dividend;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (33, '筹资活动现金流出小计', var_fin_outflow_total);

    -- 净额
    SET var_net_fin_cash_flow = var_fin_inflow_total - var_fin_outflow_total;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (34, '筹资活动产生的现金流量净额', var_net_fin_cash_flow);

    -- ====================步骤6: 期末汇总与校验 ====================
    -- 1. 现金及现金等价物净增加额
    SET var_total_net_increase = var_net_op_cash_flow + var_net_inv_cash_flow + var_net_fin_cash_flow;
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (36, '四、现金及现金等价物净增加额', var_total_net_increase);

    -- 2. 加：期初现金及现金等价物余额
    -- 公式: 取所有货币资金科目的期初余额合计
    SET var_cash_begin_balance = (SELECT COALESCE(SUM(opening_balance), 0) FROM `level1_full_summary` WHERE account_code IN ('1001', '1002', '1012'));
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (37, '  加：期初现金及现金等价物余额', var_cash_begin_balance);

    -- 3. 期末现金及现金等价物余额
    -- 公式: 取所有货币资金科目的期末余额合计 (用于校验)
    -- 也可以用公式 var_cash_begin_balance + var_total_net_increase 计算得出
    SET var_cash_end_balance = (SELECT COALESCE(SUM(closing_balance), 0) FROM `level1_full_summary` WHERE account_code IN ('1001', '1002', '1012'));
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (38, '五、期末现金及现金等价物余额', var_cash_end_balance);

    -- ==================== 步骤7: 插入标题行 ====================
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (1, '一、经营活动产生的现金流量：', NULL);
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (12, '二、投资活动产生的现金流量：', NULL);
    INSERT INTO `cash_flow_statement_report` (line_index, item, current_period_amount) VALUES (24, '三、筹资活动产生的现金流量：', NULL);

END$$
DELIMITER ;```


