// backend/static/js/reports.js 
$(document).ready(function() {
    const $displayArea = $('#report-display-area');
    const $yearInput = $('#report-year');
    const $reportButtons = $('.report-controls .btn');

    // ==================== 格式化工具函数 ====================
    function formatNumber(value) {
        if (value === null || value === undefined || parseFloat(value) === 0) {
            return '-';
        }
        return parseFloat(value).toFixed(2);
    }

    // ==================== 按钮点击样式切换逻辑 ====================
    $reportButtons.on('click', function() {
        $reportButtons.removeClass('btn-primary');
        $(this).addClass('btn-primary');
    });
    // ==================================================================

    // --- 步骤一：生成并查看科目汇总表 ---
    $('#btn-generate-summary').on('click', function() {
        const year = $yearInput.val();
        if (!year) {
            alert('请输入年份！');
            return;
        }

        $.ajax({
            url: '/api/reports/generate_summary',
            type: 'POST',
            contentType: 'application/json',
            data: JSON.stringify({ year: parseInt(year) }),
            success: function(response) {
                alert(response.message);
                fetchAndDisplaySummary(year);
            },
            error: function(xhr) { 
                alert('汇总数据生成失败: ' + (xhr.responseJSON ? xhr.responseJSON.error : '未知错误'));
            }
        });
    });

    function fetchAndDisplaySummary(year) {
        $.ajax({
            url: `/api/reports/account_summary?year=${year}`,
            type: 'GET',
            success: function(data) {
                let html = `
                    <h3>科目汇总表</h3>
                    <table border="1" style="width:100%">
                        <thead>
                            <tr>
                                <th>科目代码</th>
                                <th>科目名称</th>
                                <th>期初余额</th>
                                <th>本期借方</th>
                                <th>本期贷方</th>
                                <th>期末余额</th>
                            </tr>
                        </thead>
                        <tbody>`;
                data.forEach(function(row) {
                    html += `<tr>
                        <td>${row.account_code}</td>
                        <td>${row.account_name}</td>
                        <td>${formatNumber(row.opening_balance)}</td>
                        <td>${formatNumber(row.period_debit)}</td>
                        <td>${formatNumber(row.period_credit)}</td>
                        <td>${formatNumber(row.closing_balance)}</td>
                    </tr>`;
                });
                html += '</tbody></table>';
                $displayArea.html(html);
            },
            error: function(xhr) {
                alert('获取科目汇总表失败: ' + (xhr.responseJSON ? xhr.responseJSON.error : '未知错误'));
            }
        });
    }

    // --- 步骤二：获取并显示资产负债表 ---
    $('#btn-get-bs').on('click', function() {
        const year = $yearInput.val();
        if (!year) {
            alert('请输入年份！');
            return;
        }
        $.ajax({
            url: `/api/reports/balance_sheet?year=${year}`,
            type: 'GET',
            success: function(data) {
                // 【修正】使用反引号(`)来创建多行字符串，并移除行尾的反斜杠(\)
                let html = `
                    <h3>资产负债表</h3>
                    <table border="1" style="width:100%">
                        <thead>
                            <tr>
                                <th>资产项目</th>
                                <th>期初数</th>
                                <th>期末数</th>
                                <th>负债和所有者权益</th>
                                <th>期初数</th>
                                <th>期末数</th>
                            </tr>
                        </thead>
                        <tbody>`;
                data.forEach(function(row) {
                    html += `<tr>
                        <td style="text-align: left;">${row.asset_item || ''}</td>
                        <td style="text-align: right;">${formatNumber(row.asset_opening)}</td>
                        <td style="text-align: right;">${formatNumber(row.asset_closing)}</td>
                        <td style="text-align: left;">${row.liability_equity_item || ''}</td>
                        <td style="text-align: right;">${formatNumber(row.liability_equity_opening)}</td>
                        <td style="text-align: right;">${formatNumber(row.liability_equity_closing)}</td>
                    </tr>`;
                });
                html += '</tbody></table>';
                $displayArea.html(html);
            },
            error: function(xhr) { 
                alert('获取资产负债表失败: ' + (xhr.responseJSON ? xhr.responseJSON.error : '未知错误'));
            }
        });
    });

    // --- 步骤三：获取并显示利润表 ---
    $('#btn-get-is').on('click', function() {
        const year = $yearInput.val();
        if (!year) {
            alert('请输入年份！');
            return;
        }
        $.ajax({
            url: `/api/reports/income_statement?year=${year}`,
            type: 'GET',
            success: function(data) {
                let html = `
                    <h3>利润表</h3>
                    <p style="text-align:center;">${year}年度</p>
                    <table border="1" style="width:100%">
                        <thead>
                            <tr>
                                <th>项目</th>
                                <th>行次</th>
                                <th>金额</th>
                            </tr>
                        </thead>
                        <tbody>`;
                data.forEach(function(row) {
                    let amount = row.amount;
                    let itemText = row.item || '';
                    html += `
                            <tr>
                                <td style="text-align: left;">${itemText}</td>
                                <td>${row.line_index || ''}</td>
                                <td style="text-align: right;">${formatNumber(amount)}</td>
                            </tr>`;
                });
                html += '</tbody></table>';
                $displayArea.html(html);
            },
            error: function(xhr) { 
                alert('获取利润表失败: ' + (xhr.responseJSON ? xhr.responseJSON.error : '未知错误'));
            }
        });
    });

    // --- 步骤四：获取并显示现金流量表 ---
    $('#btn-get-cfs').on('click', function() {
        const year = $yearInput.val();
        if (!year) {
            alert('请输入年份！');
            return;
        }
        $.ajax({
            url: `/api/reports/cash_flow_statement?year=${year}`,
            type: 'GET',
            success: function(data) {
                let html = `
                    <h3>现金流量表</h3>
                    <table border="1" style="width:100%">
                        <thead>
                            <tr>
                                <th>项目</th>
                                <th>金额</th>
                            </tr>
                        </thead>
                        <tbody>`;
                data.forEach(function(row) {
                    html += `<tr>
                        <td>${row.item || ''}</td>
                        <td style="text-align: right;">${formatNumber(row.current_period_amount)}</td>
                    </tr>`;
                });
                html += '</tbody></table>';
                $displayArea.html(html);
            },
            error: function(xhr) { 
                alert('获取现金流量表失败: ' + (xhr.responseJSON ? xhr.responseJSON.error : '未知错误'));
            }
        });
    });
});

