import React from "react";
import { Table } from "antd";

const ContractRoomchange = ({ data }) => {
    // if (!data || data.length === 0) {
    //     return (
    //         <p className="text-gray-500 italic">
    //             No room change history.
    //         </p>
    //     );
    // }

    const columns = [
        {
            title: "Change Date",
            dataIndex: "changeDate",
            key: "changeDate",
            render: (value) => (
                <span className="text-teal-700 font-medium min-w-[100px] inline-block">
                    {value}
                </span>
            ),
        },
        {
            title: "From Room",
            dataIndex: "fromRoom",
            key: "fromRoom",
            render: (room) => (
                <div className="space-y-1">
                    <p><strong>Room:</strong> {room.roomNumber}</p>
                    <div
                        className="text-gray-600 text-sm line-clamp-1 overflow-hidden text-ellipsis"
                        dangerouslySetInnerHTML={{ __html: room.description }}
                    />
                </div>
            ),
        },
        {
            title: "To Room",
            dataIndex: "toRoom",
            key: "toRoom",
            render: (room) => (
                <div className="space-y-1">
                    <p><strong>Room:</strong> {room.roomNumber}</p>
                    <div
                        className="text-gray-600 text-sm line-clamp-1 overflow-hidden text-ellipsis"
                        dangerouslySetInnerHTML={{ __html: room.description }}
                    />
                </div>
            ),
        },
        {
            title: "Reason",
            dataIndex: "reason",
            key: "reason",
            render: (html) => (
                <div
                    className="text-gray-600 "
                    dangerouslySetInnerHTML={{ __html: html }}
                />
            ),
        }
    ];

    return (
        <div className="mt-2">
            <h3 className="font-semibold mb-3 text-lg">Room Change History</h3>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                pagination={false}
                bordered
            />
        </div>
    );
};

export default ContractRoomchange;
