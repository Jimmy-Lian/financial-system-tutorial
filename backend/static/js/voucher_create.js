// backend/static/js/voucher_create.js
$(document).ready(function() {
    const $tableBody = $('#entries-table tbody');
    const $totalDebit = $('#total-debit');
    const $totalCredit = $('#total-credit');
    const $voucherDate = $('#voucher-date');
    const $voucherType = $('#voucher-type');
    const $voucherNumber = $('#voucher-number');
    let accountOptions = '';

    // --- 1. 自动获取下一个凭证号的核心函数 ---
    function fetchNextVoucherNumber() {
        const date = $voucherDate.val();
        const type = $voucherType.val();

        if (date && type) {
            $.ajax({
                url: `/api/vouchers/next_number?date=${date}&type=${type}`,
                type: 'GET',
                success: function(data) {
                    $voucherNumber.val(data.next_number);
                }
            });
        }
    }

    // --- 2. 动态增加一行 ---
    function addNewRow() {
        const newRowHtml = `
            <tr>
                <td><input type="text" class="summary-input"></td>
                <td><select class="account-select">${accountOptions}</select></td>
                <td><input type="number" class="debit-input" value="0.00" step="0.01"></td>
                <td><input type="number" class="credit-input" value="0.00" step="0.01"></td>
                <td><button type="button" class="btn btn-danger btn-delete-row">删除</button></td>
            </tr>
        `;
        $tableBody.append(newRowHtml);
    }

    // --- 3. 实时计算合计 ---
    function updateTotals() {
        let totalDebit = 0;
        let totalCredit = 0;
        $tableBody.find('tr').each(function() {
            totalDebit += parseFloat($(this).find('.debit-input').val()) || 0;
            totalCredit += parseFloat($(this).find('.credit-input').val()) || 0;
        });
        $totalDebit.text(totalDebit.toFixed(2));
        $totalCredit.text(totalCredit.toFixed(2));
    }

    // --- 4. 初始化页面 ---
    function initializePage() {
        // 设置默认日期为今天
        const today = new Date().toISOString().split('T')[0];
        $voucherDate.val(today);

        // 获取末级科目
        $.ajax({
            url: '/api/accounts/leaf',
            type: 'GET',
            success: function(accounts) {
                accounts.forEach(function(acc) {
                    accountOptions += `<option value="${acc.account_code}">${acc.account_code} ${acc.account_name}</option>`;
                });
                addNewRow();
                addNewRow();
                // 在获取科目后，立即获取默认的'记'字号凭证号
                fetchNextVoucherNumber();
            }
        });
    }

    // --- 5. 绑定所有事件 ---
    // 当日期或凭证字改变时，重新获取凭证号
    $voucherDate.on('change', fetchNextVoucherNumber);
    $voucherType.on('change', fetchNextVoucherNumber);

    // 增加一行
    $('#btn-add-row').on('click', addNewRow);

    // 删除一行
    $tableBody.on('click', '.btn-delete-row', function() {
        if ($tableBody.find('tr').length > 2) {
            $(this).closest('tr').remove();
            updateTotals();
        } else {
            alert('凭证至少需要两行分录。');
        }
    });

    // 实时更新合计
    $tableBody.on('input', '.debit-input, .credit-input', updateTotals);

    // 保存凭证
    $('#voucher-form').on('submit', function(event) {
        event.preventDefault();

        // 校验
        if (parseFloat($totalDebit.text()) !== parseFloat($totalCredit.text())) {
            alert('借贷不平衡，请检查！');
            return;
        }
        if (parseFloat($totalDebit.text()) === 0) {
            alert('总金额不能为0！');
            return;
        }

        // 收集数据
        const voucherData = {
            header: {
                date: $('#voucher-date').val(),
                type: $('#voucher-type').val(),
                number: $('#voucher-number').val(),
                summary: $tableBody.find('.summary-input').first().val()
            },
            entries: []
        };

        $tableBody.find('tr').each(function() {
            const $row = $(this);
            const debit = parseFloat($row.find('.debit-input').val()) || 0;
            const credit = parseFloat($row.find('.credit-input').val()) || 0;
            if (debit > 0 || credit > 0) {
                voucherData.entries.push({
                    summary: $row.find('.summary-input').val(),
                    account_code: $row.find('.account-select').val(),
                    debit: debit,
                    credit: credit
                });
            }
        });

        // 发送AJAX请求
        $.ajax({
            url: '/api/vouchers',
            type: 'POST',
            contentType: 'application/json',
            data: JSON.stringify(voucherData),
            success: function(response) {
                alert(response.message);
                window.location.href = '/vouchers';
            },
            error: function(xhr) {
                alert('保存失败: ' + xhr.responseJSON.error);
            }
        });
    });
    
    // --- 6. 页面启动 ---
    initializePage();
});

