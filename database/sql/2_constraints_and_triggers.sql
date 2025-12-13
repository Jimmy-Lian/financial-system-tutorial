-- =================================================================
-- 清理已存在的约束和触发器 (为了让脚本可重复执行)
-- =================================================================
-- 注意：首次运行此脚本时，以下DROP语句可能会报告错误，提示约束不存在。
-- 这是正常现象，可以安全忽略。这些DROP语句的作用在于当您需要重复运行此脚本时，这些-语句将确保旧的对象被正确清理。
-- 首次运行时，前面部分的代码:从SET FOREIGN_KEY_CHECKS=0 到 SET FOREIGN_KEY_CHECKS=1 不要运行。应直接从“创建新的约束和触发器”部分开始运行。

-- 忽略外键检查，以便安全删除
SET FOREIGN_KEY_CHECKS=0;

-- 删除外键约束 (MySQL中DROP FOREIGN KEY不支持IF EXISTS)
ALTER TABLE `journal_entries` DROP FOREIGN KEY `fk_entry_account`;
ALTER TABLE `account_balances` DROP FOREIGN KEY `fk_balance_account`;

-- 删除检查约束 (MySQL中DROP CHECK不支持IF EXISTS)
ALTER TABLE `journal_entries` DROP CHECK `chk_debit_amount`;
ALTER TABLE `journal_entries` DROP CHECK `chk_credit_amount`;

-- 删除触发器 (DROP TRIGGER支持IF EXISTS)
DROP TRIGGER IF EXISTS `trg_before_insert_chart_of_accounts`;
DROP TRIGGER IF EXISTS `trg_before_update_chart_of_accounts`;
DROP TRIGGER IF EXISTS `trg_before_delete_chart_of_accounts`;

-- 重新启用外键检查
SET FOREIGN_KEY_CHECKS=1;



-- =================================================================
-- 创建新的约束和触发器
-- =================================================================

-- 为凭证分录表添加外键约束，关联到会计科目表
ALTER TABLE `journal_entries`
ADD CONSTRAINT `fk_entry_account`
FOREIGN KEY (`account_code`) REFERENCES `chart_of_accounts` (`account_code`)
ON UPDATE CASCADE ON DELETE RESTRICT;

-- 为科目余额表添加外键约束
ALTER TABLE `account_balances`
ADD CONSTRAINT `fk_balance_account`
FOREIGN KEY (`account_code`) REFERENCES `chart_of_accounts` (`account_code`)
ON DELETE CASCADE ON UPDATE CASCADE;

-- 为凭证分录表的金额字段添加检查约束
ALTER TABLE `journal_entries`
ADD CONSTRAINT `chk_debit_amount` CHECK ((`debit_amount` >= 0)),
ADD CONSTRAINT `chk_credit_amount` CHECK ((`credit_amount` >= 0));

-- ----------------------------
-- Triggers for chart_of_accounts
-- ----------------------------
DELIMITER $$

-- --- BEFORE INSERT Trigger ---
CREATE TRIGGER `trg_before_insert_chart_of_accounts`
BEFORE INSERT ON `chart_of_accounts`
FOR EACH ROW
BEGIN
    DECLARE code_len INT;
    SET code_len = CHAR_LENGTH(NEW.account_code);

    -- 根据科目代码长度计算科目级别和父级代码
    IF code_len = 4 THEN
        SET NEW.level = 1;
        SET NEW.parent_code = NULL;
    ELSEIF code_len = 6 THEN
        SET NEW.level = 2;
        SET NEW.parent_code = SUBSTRING(NEW.account_code, 1, 4);
    ELSEIF code_len = 8 THEN
        SET NEW.level = 3;
        SET NEW.parent_code = SUBSTRING(NEW.account_code, 1, 6);
    ELSEIF code_len = 10 THEN
        SET NEW.level = 4;
        SET NEW.parent_code = SUBSTRING(NEW.account_code, 1, 8);
    -- 可以根据需要继续扩展更多级别
    END IF;

    -- 校验父科目是否存在
    IF NEW.parent_code IS NOT NULL AND NOT EXISTS (SELECT 1 FROM chart_of_accounts WHERE account_code = NEW.parent_code) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '父科目代码不存在，无法添加子科目。';
    END IF;
END$$
--  SIGNAL 语句就是用来主动抛出错误的命令。开发人员通常选择 SQLSTATE '45000' 作为一种“通用”的自定义错误代码


-- --- BEFORE UPDATE Trigger ---
CREATE TRIGGER `trg_before_update_chart_of_accounts`
BEFORE UPDATE ON `chart_of_accounts`
FOR EACH ROW
BEGIN
    -- 在BEGIN之后立即声明所有变量
    DECLARE code_len INT;

    -- 如果科目代码被修改
    IF NEW.account_code != OLD.account_code THEN
        -- 检查该科目是否已被使用（作为父科目或在凭证/余额中使用）
        IF EXISTS (SELECT 1 FROM chart_of_accounts WHERE parent_code = OLD.account_code) OR
           EXISTS (SELECT 1 FROM journal_entries WHERE account_code = OLD.account_code) OR
           EXISTS (SELECT 1 FROM account_balances WHERE account_code = OLD.account_code) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '科目已被使用，禁止修改科目代码。';
        END IF;
        
        -- 重新计算级别和父级代码
        SET code_len = CHAR_LENGTH(NEW.account_code);
        IF code_len = 4 THEN
            SET NEW.level = 1;
            SET NEW.parent_code = NULL;
        ELSEIF code_len = 6 THEN
            SET NEW.level = 2;
            SET NEW.parent_code = SUBSTRING(NEW.account_code, 1, 4);
        ELSEIF code_len = 8 THEN
            SET NEW.level = 3;
            SET NEW.parent_code = SUBSTRING(NEW.account_code, 1, 6);
        ELSEIF code_len = 10 THEN
            SET NEW.level = 4;
            SET NEW.parent_code = SUBSTRING(NEW.account_code, 1, 8);
        END IF;
    END IF;
END$$


-- --- BEFORE DELETE Trigger ---
CREATE TRIGGER `trg_before_delete_chart_of_accounts`
BEFORE DELETE ON `chart_of_accounts`
FOR EACH ROW
BEGIN
    -- 检查是否存在子科目
    IF EXISTS (SELECT 1 FROM chart_of_accounts WHERE parent_code = OLD.account_code) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该科目下存在子科目，不允许删除。';
    END IF;

    -- 检查该科目是否已有业务发生
    IF EXISTS (SELECT 1 FROM journal_entries WHERE account_code = OLD.account_code) OR
       EXISTS (SELECT 1 FROM account_balances WHERE account_code = OLD.account_code) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该科目已有发生额或余额记录，不允许删除。';
    END IF;
END$$

DELIMITER ;
