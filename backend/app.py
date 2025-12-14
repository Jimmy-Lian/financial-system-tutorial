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

# --- Read all: 获取所有会计科目 ---
@app.route("/api/accounts", methods=['GET'])
def get_accounts_api():
    """获取所有会计科目的API接口"""
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "数据库连接失败"}), 500
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM chart_of_accounts ORDER BY account_code;")
        accounts = cursor.fetchall()
        return jsonify(accounts)
    except Exception as e:
        return jsonify({"error": f"查询失败: {e}"}), 500
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



if __name__ == '__main__':
    # 关键：设置 host='0.0.0.0' 以允许外部访问
    app.run(host='0.0.0.0', port=5000, debug=True)

