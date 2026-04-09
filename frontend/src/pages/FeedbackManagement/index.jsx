import React from 'react'
import { Tabs } from "antd";
import ServiceFeedbackAdmin from './ServiceFeedbackAdmin';
import ComboFeedbackAdmin from './ComboFeedBackAdmin';
import RoomFeedbackAdmin from './RoomFeedbackAdmin';

const FeedbackManagement = () => {
    const items = [
        {
            key: "1",
            label: "Room",
            children: (
                <RoomFeedbackAdmin />
            ),
        },
        {
            key: "2",
            label: "Service",
            children: (
                <ServiceFeedbackAdmin />
            ),
        },
        {
            key: "3",
            label: "Combo",
            children: (
                <ComboFeedbackAdmin />
            ),
        },
    ];
    return (
        <div className="bg-white p-6 rounded-md shadow-md">
            <h1 className="text-2xl font-bold mb-4">Feedback of Customer</h1>

            <Tabs defaultActiveKey="1" items={items} />
        </div>
    )
}

export default FeedbackManagement