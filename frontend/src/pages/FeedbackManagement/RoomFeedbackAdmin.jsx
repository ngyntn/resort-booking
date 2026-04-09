import React, { useState, useEffect } from 'react'
import apis from '@apis/index';
import { Table, Rate, Spin, Tooltip } from "antd";
import useFetch from '@src/hooks/fetch.hook';

const baseUrl = import.meta.env.VITE_API_BASE_URL;

const RoomFeedbackAdmin = () => {

    const [roomMap, setRoomMap] = useState({});

    // 👉 Fetch feedbacks
    const { data: feedbacksData, loading: isLoadingFeedbacks } = useFetch(
        () => apis.user.getFeedbacks({
            page: 1,
            limit: Number.MAX_SAFE_INTEGER,
            targetType: 'room',
        })
    );

    const feedbacks = feedbacksData?.data?.[0] || [];
    const totalFeedbacks = feedbacksData?.data?.[1] || 0;

    // 👉 Fetch Rooms để map id → Room Number - Room Type Name
    useEffect(() => {
        apis.room.getRooms({ page: 1, limit: 9999 })
            .then(res => {
                const rooms = res.data.data[0];
                const map = {};
                rooms.forEach(room => {
                    // Cú pháp an toàn để truy cập tên loại phòng
                    // Đã xác nhận qua log là room.type.name có tồn tại
                    const roomTypeName = room.type?.name || 'N/A';

                    // Lưu trữ chuỗi đã định dạng
                    map[room.id] = `${room.roomNumber} - ${roomTypeName}`;
                });
                setRoomMap(map);
            })
            .catch(error => console.error("Error fetching rooms:", error));
    }, []);

    const columns = [
        {
            title: "User",
            dataIndex: ["user", "name"],
            key: "user",
            render: (_, record) => (
                <div className="flex items-center gap-2">
                    <img
                        src={`${baseUrl}/${record.user?.avatar}`}
                        alt={`${record.user?.name}'s avatar`}
                        className="w-8 h-8 rounded-full object-cover"
                    />
                    <span>{record.user?.name}</span>
                </div>
            ),
        },
        {
            title: "Rating",
            dataIndex: "rating",
            key: "rating",
            filters: [
                { text: "⭐ 1 Star", value: 1 },
                { text: "⭐ 2 Stars", value: 2 },
                { text: "⭐ 3 Stars", value: 3 },
                { text: "⭐ 4 Stars", value: 4 },
                { text: "⭐ 5 Stars", value: 5 },
            ],
            onFilter: (value, record) => record.rating === value,
            render: (rating) => <Rate disabled value={rating} />,
        },
        {
            title: "Room",
            dataIndex: "targetId",
            key: "roomInfo",
            // Sử dụng giá trị đã được map
            render: (id) => roomMap[id] || "Unknown Room"
        },
        {
            title: "Comment",
            dataIndex: "comment",
            key: "comment",
            render: (comment) => (
                <Tooltip title={comment} className="max-w-[300px]">{comment}</Tooltip>
            ),
        },
        {
            title: "Date",
            dataIndex: "createdAt",
            key: "createdAt",
            render: (date) => new Date(date).toLocaleString(),
        },
    ];

    return (
        <div>
            {isLoadingFeedbacks ? (
                <div className="flex justify-center py-10">
                    <Spin size="large" />
                </div>
            ) : (
                <Table
                    columns={columns}
                    dataSource={feedbacks}
                    rowKey="id"
                    pagination={{
                        pageSize: 10,
                        total: totalFeedbacks,
                    }}
                />
            )}
        </div>
    )
}

export default RoomFeedbackAdmin;