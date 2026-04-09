import React, { useEffect, useState } from 'react';
import apis from '@apis/index';
import { Table, Rate, Spin, Tooltip } from "antd"; // Đã bỏ import Select
import useFetch from '@src/hooks/fetch.hook';

// Đã bỏ const { Option } = Select;
const baseUrl = import.meta.env.VITE_API_BASE_URL;

const ComboFeedbackAdmin = () => {
    const [comboMap, setComboMap] = useState({});
    // Đã loại bỏ: const [ratingFilter, setRatingFilter] = useState(null);

    // 👉 Fetch feedbacks
    const { data: feedbacksData, loading: isLoadingFeedbacks } = useFetch(
        () => apis.user.getFeedbacks({
            page: 1,
            // Giữ nguyên limit lớn để lấy toàn bộ data cho client-side filtering
            limit: Number.MAX_SAFE_INTEGER,
            targetType: 'combo',
            // Đã loại bỏ: rating: ratingFilter || undefined,
        })
    );

    const feedbacks = feedbacksData?.data?.[0] || [];
    const totalFeedbacks = feedbacksData?.data?.[1] || 0;

    // 👉 Fetch combos để map id → name
    useEffect(() => {
        apis.booking.getCombosForAll({ page: 1, limit: 9999 }).then((res) => {
            const list = res?.data?.data?.[0] || [];
            const map = {};
            list.forEach(c => {
                map[c.id] = c.name;
            });
            setComboMap(map);
        });
    }, []);

    // 👉 Columns
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
        // Đã thêm filters và onFilter cho cột Rating
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
        // Đã di chuyển lên vị trí thứ 3 (sau Rating)
        {
            title: "Combo Name",
            dataIndex: "targetId",
            key: "comboName",
            render: (id) => comboMap[id] || "Unknown combo",
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
            {/* Đã loại bỏ khối filter Select */}
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
    );
};

export default ComboFeedbackAdmin;