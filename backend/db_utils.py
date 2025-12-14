# backend/db_utils.py
import mysql.connector
from config import DB_CONFIG

def get_db_connection():
    """获取数据库连接"""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except mysql.connector.Error as err:
        print(f"数据库连接失败: {err}")
        return None
