// backend/static/js/accounts.js
$(document).ready(function() {

    const API_URL = '/api/accounts';
    const $tableBody = $('#accounts-table tbody');
    const $modal = $('#account-modal');
    const $form = $('#account-form');
    const $modalTitle = $('#modal-title');

    // --- 功能1: 加载并显示所有会计科目 (Read) ---

	function loadAccounts() {
    $.ajax({
        url: API_URL,
        type: 'GET',
        dataType: 'json', // 明确期望返回JSON
        success: function(accounts) {
            $tableBody.empty(); // 清空表格
            accounts.forEach(function(account) {
                const row = `
                    <tr>
                        <td>${account.account_code}</td>
                        <td>${account.account_name}</td>
                        <td>${account.balance_direction ==='debit' ? '借':'贷'}</td>
                        <td>${account.level}</td>
                        <td>
                            <button class="btn btn-edit" data-code="${account.account_code}">编辑</button>
                            <button class="btn btn-danger btn-delete" data-code="${account.account_code}">删除</button>
                        </td>
                    </tr>
                `;
                $tableBody.append(row);
            });
        },
        //错误处理
        error: function(xhr, status, error) {
            console.error("AJAX请求失败:", status, error);
            console.error("服务器响应:", xhr.responseText);
            alert("加载会计科目失败！请检查浏览器控制台获取详细错误信息。");
        }
    });
}
    // --- 功能2: 处理新增和编辑弹窗 ---
    // 打开新增弹窗
    $('#btn-add-account').on('click', function() {
        $modalTitle.text('新增科目');
        $form[0].reset(); // 重置表单
        $('#account-code').prop('readonly', false); // 科目代码可编辑
        $modal.show();
    });

    // 关闭弹窗
    $('.close-button').on('click', function() {
        $modal.hide();
    });

    // --- 功能3: 提交表单 (Create & Update) ---
    $form.on('submit', function(event) {
        event.preventDefault(); // 阻止表单默认提交
        
        const accountCode = $('#account-code').val();
        const isUpdate = !!$('#account-code').prop('readonly');

        const url = isUpdate ? `${API_URL}/${accountCode}` : API_URL;
        const method = isUpdate ? 'PUT' : 'POST';

        const formData = {
            account_code: accountCode,
            account_name: $('#account-name').val(),
            balance_direction: $('#balance-direction').val()
        };

        $.ajax({
            url: url,
            type: method,
            contentType: 'application/json',
            data: JSON.stringify(formData),
            success: function(response) {
                alert(response.message);
                $modal.hide();
                loadAccounts(); // 刷新表格
            },
            error: function() {
                alert('操作失败！');
            }
        });
    });

// --- 功能4: 处理编辑按钮点击 (填充表单) ---
$tableBody.on('click', '.btn-edit', function() {
    const accountCode = $(this).data('code');
    
    // 先通过API获取该科目的最新数据
    $.ajax({
        url: `${API_URL}/${accountCode}`,
        type: 'GET',
        success: function(account) {
            $modalTitle.text('编辑科目');
            $('#account-code').val(account.account_code).prop('readonly', true);
            $('#account-name').val(account.account_name);
            $('#balance-direction').val(account.balance_direction);
            $modal.show();
        },
        //  增加错误处理逻辑
        error: function(xhr) {
            // 如果请求失败，弹窗提示错误信息
            alert('获取科目信息失败: ' + (xhr.responseJSON ? xhr.responseJSON.error : '未知错误'));
        }
    });
});

    // --- 功能5: 处理删除按钮点击 (Delete) ---
    $tableBody.on('click', '.btn-delete', function() {
        if (confirm('确定要删除这个科目吗？')) {
            const accountCode = $(this).data('code');
            $.ajax({
                url: `${API_URL}/${accountCode}`,
                type: 'DELETE',
                success: function(response) {
                    alert(response.message);
                    loadAccounts(); // 刷新表格
                },
                error: function(xhr) {
                    alert('删除失败: ' + xhr.responseJSON.error);
                }
            });
        }
    });

    // 页面初始加载
    loadAccounts();
});


