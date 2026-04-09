import React, { useState, useEffect } from 'react'
import apis from '@apis/index';
import { Table, Rate, Avatar, Spin, Tooltip } from "antd";
import useFetch from '@src/hooks/fetch.hook';

const baseUrl = import.meta.env.VITE_API_BASE_URL;

const ServiceFeedbackAdmin = () => {

    const [serviceMap, setServiceMap] = useState({});

    const { data: feedbacksData, loading: isLoadingFeedbacks } = useFetch(
        () => apis.user.getFeedbacks({
            page: 1,
            limit: Number.MAX_SAFE_INTEGER,
            targetType: 'service',
        })
    );

    const feedbacks = feedbacksData?.data?.[0] || [];
    const totalFeedbacks = feedbacksData?.data?.[1] || 0;

    useEffect(() => {
        apis.service.getServices({ page: 1, limit: 999 })
            .then(res => {
                const services = res.data.data[0];
                const map = {};
                services.forEach(sv => {
                    map[sv.id] = sv.name;
                });
                setServiceMap(map);
            });
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
            title: "Service Name",
            dataIndex: "targetId",
            key: "serviceName",
            render: (id) => serviceMap[id] || "Unknown"
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

export default ServiceFeedbackAdmin;
