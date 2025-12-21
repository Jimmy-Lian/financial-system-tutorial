// backend/static/js/vouchers.js
$(document).ready(function() {
    const $tableBody = $('#vouchers-table tbody');
    const $modal = $('#voucher-details-modal');

    function formatNumber(value) {
        return parseFloat(value).toFixed(2);
    }

    function loadVouchers() {
        $.ajax({
            url: '/api/vouchers',
            type: 'GET',
            success: function(vouchers) {
                $tableBody.empty();
                vouchers.forEach(function(voucher) {
                    const row = `
                        <tr data-id="${voucher.id}" class="view-details" style="cursor: pointer;">
                            <td>${voucher.voucher_date}</td>
                            <td>${voucher.voucher_ref}</td>
                            <td>${voucher.summary}</td>
                            <td style="text-align: right;">${formatNumber(voucher.total_amount)}</td>
                            <td>
                                <button class="btn btn-danger btn-delete">删除</button>
                            </td>
                        </tr>
                    `;
                    $tableBody.append(row);
                });
            }
        });
    }

    // --- 查看凭证详情 ---
    $tableBody.on('click', '.view-details', function(event) {
        if ($(event.target).hasClass('btn-delete')) {
            return;
        }
        const voucherId = $(this).data('id');
        $.ajax({
            url: `/api/vouchers/${voucherId}`,
            type: 'GET',
            success: function(data) {
                const { header, entries } = data;
                $('#modal-voucher-ref').text(`凭证详情: ${header.voucher_type}-${String(header.voucher_number).padStart(4, '0')}`);
                $('#modal-voucher-header').html(`<p>日期: ${header.voucher_date} &nbsp;&nbsp;&nbsp; 摘要: ${header.summary}</p>`);
                
                const $entriesBody = $('#modal-entries-table tbody');
                $entriesBody.empty();
                let totalDebit = 0;
                let totalCredit = 0;

                entries.forEach(function(entry) {
                    const entryRow = `
                        <tr>
                            <td>${entry.summary}</td>
                            <td>${entry.account_code} ${entry.account_name}</td>
                            <td style="text-align: right;">${formatNumber(entry.debit_amount)}</td>
                            <td style="text-align: right;">${formatNumber(entry.credit_amount)}</td>
                        </tr>
                    `;
                    $entriesBody.append(entryRow);
                    totalDebit += parseFloat(entry.debit_amount);
                    totalCredit += parseFloat(entry.credit_amount);
                });

                $('#modal-voucher-footer').html(`<span>合计: &nbsp;&nbsp; 借方 ${formatNumber(totalDebit)} &nb
sp;&nbsp; 贷方 ${formatNumber(totalCredit)}</span>`);
                $modal.show();
            },
            error: function() {
                alert('获取凭证详情失败！');
            }
        });
    });

    // --- 关闭弹窗 ---
    $('.close-button').on('click', function() {
        $modal.hide();
    });

    // --- 删除凭证 ---
    $tableBody.on('click', '.btn-delete', function() {
        const $row = $(this).closest('tr');
        const voucherId = $row.data('id');
        if (confirm('确定要删除这张凭证吗？')) {
            $.ajax({
                url: `/api/vouchers/${voucherId}`,
                type: 'DELETE',
                success: function(response) {
                    alert(response.message);
                    $row.remove();
                },
                error: function(xhr) {
                    alert('删除失败: ' + (xhr.responseJSON ? xhr.responseJSON.error : '未知错误'));
                }
            });
        }
    });
    // --- 初始加载 ---
    loadVouchers();
});

