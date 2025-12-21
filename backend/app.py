# backend/app.py
from flask import Flask, jsonify, render_template, request
from db_utils import get_db_connection
app = Flask(__name__)
@app.route("/")
def index():
    return "财务系统后端服务已启动"

@app.route("/accounts")
def show_accounts_page():
    """
    【前后端分离模式】
    此路由现在只负责返回 'accounts.html' 页面的基本框架。
    数据将由前端通过 JavaScript 异步加载。
    """
    # 相比最初的版本，这里所有的数据库连接、查询和数据传递代码都已被移除。
    # Flask 只需找到并返回模板文件即可。
    return render_template('accounts.html')

# API 相关的路由将在 6.4 相关章节中添加。

# --- API 路由 ---
# 注意：这些路由以 /api/ 开头，以区别于页面路由

@app.route("/reports")
def show_reports_page():
    """【新增】渲染财务报表页面"""
    # 这个路由同样只负责返回页面框架，数据由前端JS异步请求API获取
    return render_template('reports.html')


# --- Read all: 获取所有会计科目 ---
@app.route("/api/accounts", methods=['GET'])
def get_accounts_api():
    """获取所有会计科目，并增加是否为末级科目的标志"""
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        # 这个SQL查询会判断每个科目是否作为其他科目的父科目出现过
        # 如果没有，则它就是末级科目 (is_leaf = 1)
        sql = """
            SELECT
                a.*,
                (CASE WHEN b.parent_code IS NULL THEN 1 ELSE 0 END) as is_leaf
            FROM
                chart_of_accounts a
            LEFT JOIN
                (SELECT DISTINCT parent_code FROM chart_of_accounts WHERE parent_code IS NOT NULL) b
            ON
                a.account_code = b.parent_code
            ORDER BY
                a.account_code;
        """
        cursor.execute(sql)
        accounts = cursor.fetchall()
        return jsonify(accounts)
    except Exception as e:
        return jsonify({"error": f"查询科目列表失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()



# --- Read: 获取单个会计科目 ---
@app.route("/api/accounts/<string:account_code>", methods=['GET'])
def get_single_account_api(account_code):
    """获取单个会计科目的API接口"""
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM chart_of_accounts WHERE account_code = %s;", (account_code,))
        account = cursor.fetchone()
        if account: return jsonify(account)
        else: return jsonify({"error": "未找到该科目"}), 404
    except Exception as e: return jsonify({"error": f"查询失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

# --- Create: 新增一个会计科目 ---
@app.route("/api/accounts", methods=['POST'])
def create_account_api():
    """新增一个会计科目"""
    data = request.get_json()
    if not data or not all(k in data for k in ['account_code', 'account_name', 'balance_direction']):
        return jsonify({"error": "缺少必要的字段"}), 400
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    cursor = conn.cursor()
    try:
        sql = "INSERT INTO chart_of_accounts (account_code, account_name, balance_direction) VALUES (%s, %s, %s)"
        cursor.execute(sql, (data['account_code'], data['account_name'], data['balance_direction']))
        conn.commit()
        return jsonify({"message": "会计科目创建成功"}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"创建失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

# --- Update: 修改一个会计科目 ---
@app.route("/api/accounts/<string:account_code>", methods=['PUT'])
def update_account_api(account_code):
    """修改一个会计科目"""
    data = request.get_json()
    if not data: return jsonify({"error": "请求体中没有提供数据"}), 400
    fields = [key for key in ['account_name', 'balance_direction'] if key in data]
    if not fields: return jsonify({"error": "没有提供可更新的字段"}), 400
    
    set_clause = ", ".join([f"{field} = %s" for field in fields])
    values = [data[field] for field in fields]
    values.append(account_code)

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    cursor = conn.cursor()
    try:
        sql = f"UPDATE chart_of_accounts SET {set_clause} WHERE account_code = %s"
        cursor.execute(sql, tuple(values))
        conn.commit()
        if cursor.rowcount == 0: return jsonify({"error": "未找到该科目"}), 404
        return jsonify({"message": "会计科目更新成功"})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"更新失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

# --- Delete: 删除一个会计科目 ---
@app.route("/api/accounts/<string:account_code>", methods=['DELETE'])
def delete_account_api(account_code):
    """删除一个会计科目"""
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM chart_of_accounts WHERE account_code = %s", (account_code,))
        conn.commit()
        if cursor.rowcount > 0: return jsonify({"message": "删除成功"})
        else: return jsonify({"error": "未找到该科目"}), 404
    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"删除失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

# --- API 路由：期初余额管理 ---
@app.route("/api/account_balances", methods=['GET'])
def get_account_balances_api():
    """根据年份获取所有科目的期初余额，并判断是否为初始年份"""
    year = request.args.get('year', type=int)
    if not year: return jsonify({"error": "必须提供年份参数"}), 400

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT MIN(fiscal_year) as min_year FROM account_balances WHERE opening_balance != 0 OR period_debit != 0 OR period_credit != 0")
        result = cursor.fetchone()
        min_year = result['min_year'] if result and result['min_year'] is not None else year
        is_initial_year = (year <= min_year)

        sql = """
            SELECT coa.account_code, ab.opening_balance
            FROM chart_of_accounts coa
            LEFT JOIN account_balances ab ON coa.account_code = ab.account_code AND ab.fiscal_year = %s
            ORDER BY coa.account_code;
        """
        cursor.execute(sql, (year,))
        balances = cursor.fetchall()
        balance_map = {b['account_code']: b['opening_balance'] for b in balances}

        return jsonify({
            "balances": balance_map,
            "is_initial_year": is_initial_year
        })
    except Exception as e:
        return jsonify({"error": f"查询期初余额失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/account_balances", methods=['POST'])
def save_account_balances_api():
    """批量保存或更新指定年份的期初余额"""
    data = request.get_json()
    year = data.get('year')
    balances = data.get('balances')
    if not year or balances is None:
        return jsonify({"error": "缺少年份或余额数据"}), 400

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor()
    try:
        sql = """
            INSERT INTO account_balances (account_code, fiscal_year, opening_balance)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE opening_balance = VALUES(opening_balance)
        """
        data_to_insert = [(item['account_code'], year, item['balance']) for item in balances]
        cursor.executemany(sql, data_to_insert)
        conn.commit()
        return jsonify({"message": f"{year}年度的期初余额已成功保存"})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"保存期初余额失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()


# --- 财务报表生成的 API 路由 ---

@app.route("/api/reports/generate_summary", methods=['POST'])
def generate_summary_api():
    """调用存储过程，计算指定年度的科目汇总数据"""
    data = request.get_json()
    year = data.get('year')
    if not year:
        return jsonify({"error": "必须提供年份"}), 400
    
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor()
    try:
        cursor.callproc('proc_generate_account_summary', (year,))
        conn.commit()
        return jsonify({"message": f"{year}年度科目汇总数据已生成"})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"汇总计算失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/reports/account_summary", methods=['GET'])
def get_account_summary_api():
    """获取指定年度的科目汇总表数据"""
    year = request.args.get('year', type=int)
    if not year:
        return jsonify({"error": "必须提供年份参数"}), 400

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        sql = """
            SELECT ab.account_code, coa.account_name, ab.opening_balance, 
                   ab.period_debit, ab.period_credit, ab.closing_balance
            FROM account_balances ab
            JOIN chart_of_accounts coa ON ab.account_code = coa.account_code
            WHERE ab.fiscal_year = %s ORDER BY ab.account_code;
        """
        cursor.execute(sql, (year,))
        summary_data = cursor.fetchall()
        return jsonify(summary_data)
    except Exception as e:
        return jsonify({"error": f"获取科目汇总表失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/reports/balance_sheet", methods=['GET'])
def get_balance_sheet_api():
    """获取资产负债表数据"""
    year = request.args.get('year', type=int)
    if not year: return jsonify({"error": "必须提供年份参数"}), 400

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        # 注意: 某些数据库驱动可能需要分别处理callproc和后续查询
        cursor.callproc('proc_generate_balance_sheet', (year,))
        # 清理可能存在的上一个查询结果
        for _ in cursor.stored_results():
            pass
        cursor.execute("SELECT * FROM balance_sheet_report ORDER BY line_index;")
        report_data = cursor.fetchall()
        return jsonify(report_data)
    except Exception as e:
        return jsonify({"error": f"获取报表失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/reports/income_statement", methods=['GET'])
def get_income_statement_api():
    """获取利润表数据"""
    year = request.args.get('year', type=int)
    if not year: return jsonify({"error": "必须提供年份参数"}), 400
        
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.callproc('proc_generate_income_statement', (year,))
        for _ in cursor.stored_results():
            pass
        cursor.execute("SELECT * FROM income_statement_report ORDER BY line_index;")
        report_data = cursor.fetchall()
        return jsonify(report_data)
    except Exception as e:
        return jsonify({"error": f"获取报表失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/reports/cash_flow_statement", methods=['GET'])
def get_cash_flow_statement_api():
    """获取现金流量表数据"""
    year = request.args.get('year', type=int)
    if not year: return jsonify({"error": "必须提供年份参数"}), 400
    
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.callproc('proc_generate_cash_flow_statement', (year,))
        for _ in cursor.stored_results():
            pass
        cursor.execute("SELECT item, current_period_amount FROM cash_flow_statement_report ORDER BY line_index;")
        report_data = cursor.fetchall()
        return jsonify(report_data)
    except Exception as e:
        return jsonify({"error": f"获取现金流量表失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/reports/trial_balance", methods=['GET'])
def get_trial_balance_api():
    """获取试算平衡表数据"""
    year = request.args.get('year', type=int)
    if not year:
        return jsonify({"error": "必须提供年份参数"}), 400

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.callproc('proc_generate_trial_balance', (year,))
        cursor.execute("SELECT * FROM trial_balance_report;")
        report_data = cursor.fetchall()
        conn.commit() # 确保存储过程的结果对当前会话可见
        return jsonify(report_data)
    except Exception as e:
        return jsonify({"error": f"获取试算平衡表失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

# ==========================================
# 10.3 记账凭证功能后端实现
# ==========================================

# --- 1. 页面路由：用于显示 HTML 页面 ---

@app.route("/vouchers")
def vouchers_page():
    """【页面】渲染并显示凭证列表页面"""
    return render_template("vouchers.html")

@app.route("/vouchers/new")
def voucher_new_page():
    """【页面】渲染并显示凭证录入页面"""
    # 确保此处指向你实际的 HTML 文件名 voucher_create.html
    return render_template("voucher_create.html")


# --- 2. API 路由：记账凭证数据管理 ---

@app.route("/api/vouchers", methods=['GET'])
def get_vouchers_api():
    """【API】获取凭证列表（含合计金额）"""
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        # SQL说明：查询凭证主表，并通过子查询计算每张凭证的借方合计
        sql = """
            SELECT 
                v.id,
                v.voucher_date,
                CONCAT(v.voucher_type, '-', LPAD(v.voucher_number, 4, '0')) as voucher_ref,
                v.summary,
                (SELECT SUM(je.debit_amount) FROM journal_entries je WHERE je.voucher_id = v.id) as total_amount
            FROM vouchers v
            ORDER BY v.voucher_date DESC, v.voucher_number DESC;
        """
        cursor.execute(sql)
        vouchers = cursor.fetchall()
        return jsonify(vouchers)
    except Exception as e:
        return jsonify({"error": f"查询凭证列表失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/vouchers/<int:voucher_id>", methods=['GET'])
def get_voucher_details_api(voucher_id):
    """【API】获取单张凭证的详细信息（头+分录）"""
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor(dictionary=True)
    try:
        # 1. 查询凭证头
        cursor.execute("SELECT * FROM vouchers WHERE id = %s", (voucher_id,))
        header = cursor.fetchone()
        if not header:
            return jsonify({"error": "未找到该凭证"}), 404

        # 2. 查询该凭证关联的所有会计分录
        sql_entries = """
            SELECT je.*, coa.account_name 
            FROM journal_entries je
            JOIN chart_of_accounts coa ON je.account_code = coa.account_code
            WHERE je.voucher_id = %s 
            ORDER BY je.id;
        """
        cursor.execute(sql_entries, (voucher_id,))
        entries = cursor.fetchall()

        return jsonify({ "header": header, "entries": entries })
    except Exception as e:
        return jsonify({"error": f"查询凭证详情失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

# --- 关键补丁：获取末级科目接口 ---
@app.route("/api/accounts/leaf", methods=['GET'])
def get_leaf_accounts_api():
    """【API】获取所有末级科目（用于录入页面的下拉框）"""
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    cursor = conn.cursor(dictionary=True)
    try:
        # SQL逻辑：找出那些没有出现在 parent_code 列中的科目
        sql = """
            SELECT account_code, account_name 
            FROM chart_of_accounts 
            WHERE account_code NOT IN (
                SELECT DISTINCT parent_code FROM chart_of_accounts WHERE parent_code IS NOT NULL
            )
            ORDER BY account_code;
        """
        cursor.execute(sql)
        accounts = cursor.fetchall()
        return jsonify(accounts)
    except Exception as e:
        return jsonify({"error": f"获取末级科目失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/vouchers/next_number", methods=['GET'])
def get_next_voucher_number_api():
    """【API】获取下一个可用的凭证号"""
    voucher_date_str = request.args.get('date')
    voucher_type = request.args.get('type')

    if not voucher_date_str or not voucher_type:
        return jsonify({"error": "必须提供日期和凭证字参数"}), 400

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500

    cursor = conn.cursor()
    try:
        # 统计当月该字号下的最大凭证号
        sql = """
            SELECT MAX(voucher_number) FROM vouchers
            WHERE voucher_type = %s AND DATE_FORMAT(voucher_date, '%%Y-%%m') = DATE_FORMAT(%s, '%%Y-%%m');
        """
        cursor.execute(sql, (voucher_type, voucher_date_str))
        max_number = cursor.fetchone()[0]

        next_number = (max_number or 0) + 1
        return jsonify({"next_number": next_number})
    except Exception as e:
        return jsonify({"error": f"计算凭证号失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/vouchers", methods=['POST'])
def create_voucher_api():
    """【API】保存新凭证（使用数据库事务控制）"""
    data = request.get_json()
    if not data: return jsonify({"error": "请求体为空"}), 400
    
    header = data.get('header')
    entries = data.get('entries')

    if not header or not entries:
        return jsonify({"error": "凭证头或分录数据缺失"}), 400

    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor()
    try:
        # --- 核心：启动事务 ---
        conn.start_transaction()

        # 1. 插入凭证主表
        sql_header = "INSERT INTO vouchers (voucher_date, voucher_type, voucher_number, summary) VALUES (%s, %s, %s, %s)"
        cursor.execute(sql_header, (header['date'], header['type'], header['number'], header['summary']))
        voucher_id = cursor.lastrowid # 获取生成的主键 ID

        # 2. 批量插入分录明细表
        sql_entries = "INSERT INTO journal_entries (voucher_id, account_code, summary, debit_amount, credit_amount) VALUES (%s, %s, %s, %s, %s)"
        entry_data = [(voucher_id, e['account_code'], e['summary'], e['debit'], e['credit']) for e in entries]
        cursor.executemany(sql_entries, entry_data)

        # 3. 提交事务
        conn.commit()
        return jsonify({"message": "凭证保存成功", "voucher_id": voucher_id}), 201
    except Exception as e:
        # 出错则回滚，确保数据一致性
        conn.rollback() 
        return jsonify({"error": f"凭证保存失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/vouchers/<int:voucher_id>", methods=['DELETE'])
def delete_voucher_api(voucher_id):
    """【API】删除凭证"""
    conn = get_db_connection()
    if conn is None: return jsonify({"error": "数据库连接失败"}), 500
    
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM vouchers WHERE id = %s", (voucher_id,))
        conn.commit()
        if cursor.rowcount > 0:
            return jsonify({"message": "凭证删除成功"})
        else:
            return jsonify({"error": "未找到该凭证"}), 404
    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"删除失败: {e}"}), 500
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    # 关键：设置 host='0.0.0.0' 以允许外部访问
    app.run(host='0.0.0.0', port=5000, debug=True)

