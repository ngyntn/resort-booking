import React, { useEffect, useState, useCallback } from "react";
import { Card, Image, Tag } from "antd";
import useFetch from "@src/hooks/fetch.hook";
import apis from "@apis/index";
import Cookies from 'js-cookie';
import { useNavigate } from 'react-router';
import { Button } from '@ui/button';
import { toast } from 'react-toastify';
import { RoomDetailDialog } from './RoomDetailDialog';

const baseUrl = import.meta.env.VITE_API_BASE_URL;

const RecommendRoomList = () => {
    const navigate = useNavigate();
    const [rooms, setRooms] = useState([])
    const [selectedRoom, setSelectedRoom] = useState(null);

    const fetchRooms = useCallback(
        () => apis.room.getRecommendRoom({ page: 1, limit: 10 }),
        []
    );

    const { data } = useFetch(fetchRooms);

    const fetchCombos = useCallback(
    () => apis.booking.getCombosForAll({ page: 1, limit: Number.MAX_SAFE_INTEGER }),
    []
    );

    const { data: comboData } = useFetch(fetchCombos);


    const handleBookRoom = (room) => {
        navigate(`/booking-confirmation/${room.id}`)
    }

    const matchedCombos = React.useMemo(() => {
        if (!selectedRoom || !comboData?.data?.[0]) return [];

        return comboData.data[0].filter(
            combo => combo.roomTypeId === selectedRoom.typeId
        );
    }, [selectedRoom, comboData]);

    useEffect(() => {
        setRooms(data?.data?.[0] || [])
    }, [data])


    return (
        <>
            {
                rooms.map((room) => (
                    <>
                        <div className="mb-6">
                            <Card
                                key={room.id}
                                hoverable
                                className="rounded-xl shadow-md border border-gray-100 "
                                cover={
                                    <Image
                                        src={`${baseUrl}/${room.media[0]?.path || 'placeholder.svg'}`}
                                        height={200}
                                        className="object-cover w-full rounded-t-xl"
                                        fallback="https://via.placeholder.com/300x200?text=No+Image"
                                    />
                                }
                            >
                                <h2 className="text-lg font-semibold">{room.roomNumber}</h2>

                                <p className="text-gray-500 mb-2">
                                    Type: <span className="font-medium">{room.type?.name}</span>
                                </p>

                                <Tag color="green">
                                    Price: ${room.price}
                                </Tag>
                                <Tag color="blue">
                                    Max people: {room.maxPeople}
                                </Tag>

                                <div
                                    className="mt-3 text-gray-600 text-sm"
                                    dangerouslySetInnerHTML={{ __html: room.description }}
                                ></div>
                                <Button
                                    size="sm"
                                    className="flex-1 bg-teal-600 hover:bg-teal-700 mt-4"
                                    onClick={() => {
                                        const accessToken = Cookies.get('accessToken');
                                        if (!accessToken) {
                                            toast.warning('Please log in before booking a room!');
                                            setTimeout(() => navigate('/login'), 3000);
                                            return;
                                        }
                                        handleBookRoom(room);
                                    }}
                                >
                                    Book Room
                                </Button>
                                <Button
                                    variant="outline"
                                    size="sm"
                                    className="flex-1 bg-teal-600 hover:bg-teal-700 mt-4 ml-4 bg-transparent text-teal-600 border border-teal-600 hover:bg-teal-50"
                                    onClick={() => setSelectedRoom(room)}
                                >
                                    View Detail
                                </Button>
                            </Card>
                        </div>
                        {/* Room Detail Modal */}
                        {!!selectedRoom && (
                        <RoomDetailDialog
                            selectedRoom={selectedRoom}
                            setSelectedRoom={setSelectedRoom}
                            handleBookRoom={handleBookRoom}
                            comboList={matchedCombos}
                        />
                        )}
                    </>
                ))
            }
        </>
    );
};




export default RecommendRoomList;
