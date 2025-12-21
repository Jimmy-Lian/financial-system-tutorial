-- =================================================================
-- 附录A-1：标准化会计科目表初始化脚本
-- =================================================================
-- 说明：
-- 1. 本脚本用于向 chart_of_accounts 表中插入一套符合通用会计准则的、规范的一级科目。
-- 2. 执行本脚本前，请确保已在 financial_db 数据库中创建了 chart_of_accounts 表。
-- 3. 脚本会首先清空科目表，以确保数据纯净。
-- 4. 科目的 `level` 和 `parent_code` 字段将由我们在第四章创建的触发器自动计算和填充。
-- =================================================================

-- 使用目标数据库
USE financial_db;

-- 为安全起见，先禁用外键检查，清空表后重新启用
SET FOREIGN_KEY_CHECKS=0;
TRUNCATE TABLE `chart_of_accounts`;
SET FOREIGN_KEY_CHECKS=1;

-- 插入会计科目数据
INSERT INTO `chart_of_accounts` (`account_code`, `account_name`, `balance_direction`) VALUES
-- 资产类 (Assets)
('1001', '库存现金', 'debit'),
('1002', '银行存款', 'debit'),
('1004', '备用金', 'debit'),
('1101', '交易性金融资产', 'debit'),
('1121', '应收票据', 'debit'),
('1122', '应收账款', 'debit'),
('1221', '其他应收款', 'debit'),
('1231', '坏账准备', 'credit'),
('1401', '材料采购', 'debit'),
('1402', '在途物资', 'debit'),
('1403', '原材料', 'debit'),
('1404', '材料成本差异', 'debit'),
('1405', '库存商品', 'debit'),
('1406', '发出商品', 'debit'),
('1408', '委托加工物资', 'debit'),
('1411', '周转材料', 'debit'),
('1471', '存货跌价准备', 'credit'),
('1511', '长期股权投资', 'debit'),
('1601', '固定资产', 'debit'),
('1602', '累计折旧', 'credit'),
('1603', '固定资产减值准备', 'credit'),
('1604', '在建工程', 'debit'),
('1605', '工程物资', 'debit'),
('1606', '固定资产清理', 'debit'),
('1701', '无形资产', 'debit'),
('1702', '累计摊销', 'credit'),
('1703', '无形资产减值准备', 'credit'),
('1901', '待处理财产损溢', 'debit'),

-- 负债类 (Liabilities)
('2001', '短期借款', 'credit'),
('2201', '应付票据', 'credit'),
('2202', '应付账款', 'credit'),
('2205', '预收账款', 'credit'),
('2211', '应付职工薪酬', 'credit'),
('2221', '应交税费', 'credit'),
('2231', '应付利息', 'credit'),
('2232', '应付股利', 'credit'),
('2241', '其他应付款', 'credit'),
('2245', '待转销项税额', 'credit'),
('2414', '持有待售负债', 'credit'),
('2501', '长期借款', 'credit'),
('2502', '应付债券', 'credit'),
('2801', '长期应付款', 'credit'),
('2802', '未确认融资费用', 'debit'),

-- 所有者权益类 (Equity)
('4001', '实收资本', 'credit'),
('4002', '资本公积', 'credit'),
('4003', '其他综合收益', 'credit'),
('4101', '盈余公积', 'credit'),
('4103', '本年利润', 'credit'),
('4104', '利润分配', 'credit'),

-- 成本类 (Costs)
('5001', '生产成本', 'debit'),
('5201', '制造费用', 'debit'),
('5301', '劳务成本', 'debit'),
('5401', '研发支出', 'debit'),

-- 损益类 (Profit & Loss)
('6001', '主营业务收入', 'credit'),
('6051', '其他业务收入', 'credit'),
('6111', '投资收益', 'credit'),
('6115', '公允价值变动损益', 'credit'),
('6117', '资产处置收益', 'credit'),
('6301', '营业外收入', 'credit'),
('6401', '主营业务成本', 'debit'),
('6402', '其他业务成本', 'debit'),
('6601', '税金及附加', 'debit'),
('6602', '销售费用', 'debit'),
('6603', '管理费用', 'debit'),
('6604', '财务费用', 'debit'),
('6701', '营业外支出', 'debit'),
('6711', '所得税费用', 'debit'),
('6901', '以前年度损益调整', 'debit');


-- =================================================================
-- 附录A-2：完整会计周期测试凭证SQL脚本
-- =================================================================
-- 说明：
-- 1. 执行本脚本前，请确保已在 financial_db 数据库中创建了所有表，
--    并已执行了“标准化会计科目表初始化脚本”。
-- 2. 本脚本将首先清空凭证和分录表，然后插入一套完整的、用于测试的示例数据。
-- 3. 假设会计年度为 2025 年。
-- =================================================================

-- 本SQL脚本根据以下经济业务写的分录

-- 1 2025年12月1日，公司成立，股东投入300万组建公司

-- 2 2日 公司向银行借款100万

-- 3 3日 购买库存商品一批，总价500万

-- 4 4日 购买固定资产一套，总价30万

-- 5 5日 销售库存商品，销售额150万，核算本次业务成本60万

-- 6  6日 支付水电费6020元

-- 7 7日 销售库存商品，销售额300万，本此业务成本130万

-- 8  8日 支付场地租金20000元

-- 9  9日 支付广告费用30000元

-- 10 10日 支付工资100000元

-- 11 15日 销售库存商品一批，总价20万，本次业务成本12万

-- 12  30日 支付办公司300元

-- 13 结转本月利润

-- 14 结转本年利润

-- 使用目标数据库

USE financial_db;

-- 清空旧数据以确保环境纯净
SET FOREIGN_KEY_CHECKS=0;
TRUNCATE TABLE `journal_entries`;
TRUNCATE TABLE `vouchers`;
SET FOREIGN_KEY_CHECKS=1;

-- ----------------------------
-- 1. 2025年12月1日，公司成立，股东投入300万组建公司
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-01', '收', 1, '收到股东投入资本金800万元');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '1002', '银行存款增加', 8000000.00, 0.00),
(@v_id, '4001', '实收资本增加', 0.00, 8000000.00);

-- ----------------------------
-- 2. 2日 公司向银行借款100万
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-02', '收', 2, '收到银行短期借款100万元');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '1002', '银行存款增加', 1000000.00, 0.00),
(@v_id, '2001', '短期借款增加', 0.00, 1000000.00);

-- ----------------------------
-- 3. 3日 购买库存商品一批，总价500万
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-03', '付', 1, '银行转账购买库存商品一批');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '1405', '库存商品增加', 5000000.00, 0.00),
(@v_id, '1002', '银行存款减少', 0.00, 5000000.00);

-- ----------------------------
-- 4. 4日 购买固定资产一套，总价30万
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-04', '付', 2, '银行转账购买固定资产一套');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '1601', '固定资产增加', 300000.00, 0.00),
(@v_id, '1002', '银行存款减少', 0.00, 300000.00);

-- ----------------------------
-- 5. 5日 销售库存商品，销售额150万，核算本次业务成本60万
-- ----------------------------
-- 凭证一：确认收入
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-05', '收', 3, '销售商品一批，收入150万');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '1002', '银行存款增加', 1500000.00, 0.00),
(@v_id, '6001', '主营业务收入增加', 0.00, 1500000.00);
-- 凭证二：结转成本
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-05', '转', 1, '结转已售商品成本60万');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6401', '主营业务成本增加', 600000.00, 0.00),
(@v_id, '1405', '库存商品减少', 0.00, 600000.00);

-- ----------------------------
-- 6. 6日 支付水电费6020元
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-06', '付', 3, '现金支付水电费');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6603', '管理费用增加', 6020.00, 0.00),
(@v_id, '1001', '库存现金减少', 0.00, 6020.00);

-- ----------------------------
-- 7. 7日 销售库存商品，销售额300万，本次业务成本130万
-- ----------------------------
-- 凭证一：确认收入
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-07', '收', 4, '销售商品一批，收入300万');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '1002', '银行存款增加', 3000000.00, 0.00),
(@v_id, '6001', '主营业务收入增加', 0.00, 3000000.00);
-- 凭证二：结转成本
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-07', '转', 2, '结转已售商品成本130万');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6401', '主营业务成本增加', 1300000.00, 0.00),
(@v_id, '1405', '库存商品减少', 0.00, 1300000.00);

-- ----------------------------
-- 8. 8日 支付场地租金20000元
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-08', '付', 4, '银行转账支付场地租金');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6603', '管理费用增加', 20000.00, 0.00),
(@v_id, '1002', '银行存款减少', 0.00, 20000.00);

-- ----------------------------
-- 9. 9日 支付广告费用30000元
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-09', '付', 5, '银行转账支付广告费用');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6602', '销售费用增加', 30000.00, 0.00),
(@v_id, '1002', '银行存款减少', 0.00, 30000.00);

-- ----------------------------
-- 10. 10日 支付工资100000元
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-10', '付', 6, '银行转账支付工资');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6603', '管理费用增加', 100000.00, 0.00),
(@v_id, '1002', '银行存款减少', 0.00, 100000.00);

-- ----------------------------
-- 11. 15日 销售库存商品一批，总价20万，本次业务成本12万
-- ----------------------------
-- 凭证一：确认收入
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-15', '收', 5, '销售商品一批，收入20万');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '1002', '银行存款增加', 200000.00, 0.00),
(@v_id, '6001', '主营业务收入增加', 0.00, 200000.00);
-- 凭证二：结转成本
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-15', '转', 3, '结转已售商品成本12万');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6401', '主营业务成本增加', 120000.00, 0.00),
(@v_id, '1405', '库存商品减少', 0.00, 120000.00);

-- ----------------------------
-- 12. 30日 支付办公费300元
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-30', '付', 7, '现金支付办公费');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6603', '管理费用增加', 300.00, 0.00),
(@v_id, '1001', '库存现金减少', 0.00, 300.00);

-- ----------------------------
-- 13. 31日 结转本月利润
-- 计算：
-- 总收入(6001) = 150 + 300 + 20 = 470万
-- 总成本(6401) = 60 + 130 + 12 = 202万
-- 销售费用(6602) = 3万
-- 管理费用(6603) = 0.602 + 2 + 10 + 0.03 = 12.632万
-- 本月利润 = 470 - 202 - 3 - 12.632 = 252.368万
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-31', '转', 4, '结转本月损益');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '6001', '结转主营业务收入', 4700000.00, 0.00),
(@v_id, '6401', '结转主营业务成本', 0.00, 2020000.00),
(@v_id, '6602', '结转销售费用', 0.00, 30000.00),
(@v_id, '6603', '结转管理费用', 0.00, 126320.00),
(@v_id, '4103', '结转利润至本年利润', 0.00, 2523680.00);

-- ----------------------------
-- 14. 31日 结转本年利润 (假设年末，将本年利润转入利润分配)
-- ----------------------------
INSERT INTO `vouchers` (`voucher_date`, `voucher_type`, `voucher_number`, `summary`) 
VALUES ('2025-12-31', '转', 5, '结转本年利润至利润分配');
SET @v_id = LAST_INSERT_ID();
INSERT INTO `journal_entries` (`voucher_id`, `account_code`, `summary`, `debit_amount`, `credit_amount`) VALUES
(@v_id, '4103', '结转本年利润', 2523680.00, 0.00),
(@v_id, '4104', '转入利润分配', 0.00, 2523680.00);






