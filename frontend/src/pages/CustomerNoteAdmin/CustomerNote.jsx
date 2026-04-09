import React, { useState, useCallback, useEffect } from 'react';
import apis from "@apis/index";
import useFetch from "@src/hooks/fetch.hook";
import { Table, Tag, Spin, Alert, Modal, Form, Input, Button, message } from "antd";
import { EditOutlined } from '@ant-design/icons';

const { TextArea } = Input;

// Component chính
const CustomerNote = () => {
    // State cho việc quản lý Modal và dữ liệu đang chỉnh sửa
    const [isModalVisible, setIsModalVisible] = useState(false);
    const [editingUser, setEditingUser] = useState(null);
    const [form] = Form.useForm();
    const [isSaving, setIsSaving] = useState(false); // State cho trạng thái lưu

    // 1. STATE MỚI: Dữ liệu khách hàng đã được lọc, dùng cho Table
    const [filteredUsers, setFilteredUsers] = useState([]);


    // Fetch dữ liệu người dùng
    const {
        data: fetchResult,
        loading: isLoadingUser,
        error,
        reFetch // Tải lại dữ liệu sau khi cập nhật
    } = useFetch(
        () => apis.user.getUsers({
            page: 1,
            limit: Number.MAX_SAFE_INTEGER,
        })
    );

    // 2. EFFECT: Xử lý dữ liệu, lọc và cập nhật state Table khi fetchResult thay đổi
    useEffect(() => {
        const usersData = fetchResult?.data?.[0] || [];

        // Lọc chỉ lấy khách hàng (role: 'customer') và đang hoạt động (status: 'active')
        const data = usersData.filter(user =>
            user.role === 'customer' && user.status === 'active'
        );

        setFilteredUsers(data);
    }, [fetchResult]); // Chạy lại khi dữ liệu fetch về thay đổi


    // 3. Mở Modal và đặt dữ liệu người dùng hiện tại
    const handleEditNote = useCallback((user) => {
        setEditingUser(user);
        setIsModalVisible(true);
        form.setFieldsValue({
            id: user.id,
            name: user.name,
            note: user.note,
        });
    }, [form]);

    // 4. Xử lý lưu ghi chú (Đã thêm Optimistic Update)
    const handleSaveNote = async (values) => {
        if (!editingUser) return;

        setIsSaving(true);

        try {
            const payload = {
                note: values.note
            };

            await apis.user.updateNoteUser(editingUser.id, payload);

            // >>> BƯỚC QUAN TRỌNG: Cập nhật state cục bộ ngay lập tức <<<
            setFilteredUsers(prevUsers => prevUsers.map(user =>
                user.id === editingUser.id
                    ? { ...user, note: values.note } // Cập nhật ghi chú mới
                    : user
            ));

            message.success(`Cập nhật ghi chú cho ${editingUser.name} thành công!`);
            setIsModalVisible(false);
            setEditingUser(null);

            // reFetch() vẫn được giữ lại để đảm bảo đồng bộ với backend sau khi cập nhật local
            reFetch();
        } catch (apiError) {
            console.error("Lỗi khi cập nhật ghi chú:", apiError);
            message.error(`Lỗi khi cập nhật ghi chú: ${apiError.message || 'Lỗi không xác định'}`);
        } finally {
            setIsSaving(false);
        }
    };

    // 5. Định nghĩa cột cho Ant Design Table (Không thay đổi)
    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', sorter: (a, b) => a.id - b.id, width: 80, fixed: 'left' },
        { title: 'Name', dataIndex: 'name', key: 'name', fixed: 'left' },
        { title: 'Email', dataIndex: 'email', key: 'email', responsive: ['md'] },
        { title: 'Phone', dataIndex: 'phone', key: 'phone', responsive: ['lg'] },
        {
            title: 'Tier',
            dataIndex: ['userTier', 'tierName'],
            key: 'userTier',
            render: (tierName) => (
                <Tag color="purple">{tierName || 'N/A'}</Tag>
            ),
            responsive: ['md'],
        },
        {
            title: 'Confirmed Bookings',
            dataIndex: 'confirmedBookingCount',
            key: 'confirmedBookingCount',
            sorter: (a, b) => (a.confirmedBookingCount || 0) - (b.confirmedBookingCount || 0),
            responsive: ['md'],
        },
        {
            title: 'Spended ($)',
            dataIndex: 'totalSpent',
            key: 'totalSpent',
            sorter: (a, b) => parseFloat(a.totalSpent || 0) - parseFloat(b.totalSpent || 0),
            render: (totalSpent) => `$${parseFloat(totalSpent || 0).toFixed(2)}`,
            responsive: ['lg'],
        },
        {
            title: 'Note',
            dataIndex: 'note',
            key: 'note',
            render: (text) => text || 'No note yet',
            responsive: ['md'],
            width: 250,
        },
        {
            title: 'Action',
            key: 'action',
            fixed: 'right',
            width: 100,
            render: (text, record) => (
                <Button
                    icon={<EditOutlined />}
                    onClick={() => handleEditNote(record)}
                    type="primary"
                >

                </Button>
            ),
        },
    ];

    if (isLoadingUser) {
        return <Spin tip="Loading data..." size="large" />;
    }

    if (error) {
        return <Alert message="Some thing wrong while loading data" description={error.message} type="error" showIcon />;
    }

    return (
        <div style={{ padding: '20px' }}>
            <h2 style={{ marginBottom: '20px' }}>📋 Customer and note</h2>
            <Table
                columns={columns}
                // SỬ DỤNG STATE ĐÃ ĐƯỢC CẬP NHẬT TRỰC TIẾP
                dataSource={filteredUsers}
                rowKey="id"
                loading={isLoadingUser}
                pagination={{ pageSize: 10 }}
                scroll={{ x: 1300 }}
                bordered
            />

            {/* Modal Chỉnh Sửa Ghi Chú */}
            <Modal
                title={`Take note for: ${editingUser?.name || ''}`}
                visible={isModalVisible}
                onCancel={() => setIsModalVisible(false)}
                footer={null}
                maskClosable={!isSaving}
            >
                <Form
                    form={form}
                    layout="vertical"
                    onFinish={handleSaveNote}
                >
                    <Form.Item label="ID Customer">
                        <Input disabled value={editingUser?.id} />
                    </Form.Item>

                    <Form.Item
                        name="note"
                        label="New note"
                    >
                        <TextArea rows={4} placeholder="Input note..." />
                    </Form.Item>

                    <Form.Item style={{ textAlign: 'right' }}>
                        <Button onClick={() => setIsModalVisible(false)} style={{ marginRight: 8 }} disabled={isSaving}>
                            Cancel
                        </Button>
                        <Button type="primary" htmlType="submit" loading={isSaving}>
                            {isSaving ? 'Saving...' : 'Save note'}
                        </Button>
                    </Form.Item>
                </Form>
            </Modal>
        </div>
    );
}

export default CustomerNote;