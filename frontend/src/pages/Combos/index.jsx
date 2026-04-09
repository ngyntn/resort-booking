import React, { useState, useEffect } from 'react';
import useFetch from '@src/hooks/fetch.hook';
import apis from '@apis/index';
import { Card, Image, Tag, Modal, Divider, Rate, Spin, Avatar, Empty } from 'antd';
import { Button } from '@ui/button';
import { useNavigate } from 'react-router';
import Cookies from 'js-cookie';
import { toast } from 'react-toastify';
import { Eye, MapPin, Users, Heart } from 'lucide-react';

const Combos = () => {
    const navigate = useNavigate();
    const [open, setOpen] = useState(false);
    const [selectedCombo, setSelectedCombo] = useState(null);
    const { data: listComboFromAPI } = useFetch(() => apis.booking.getCombosForAll({ page: 1, limit: 1000 }))
    const { data: feedbackRes, loading: loadingFeedbacks } = useFetch(
        () =>
            apis.user.getFeedbacks({
            page: 1,
            limit: 1000,
            targetType: 'combo',
            }),
    );  

    const handleBookCombo = (combo) => {
        navigate(`/booking-combo/${combo.id}`, {
            state: { combo },
        });
    };

    const comboFeedbacks = React.useMemo(() => {
        if (!feedbackRes || !selectedCombo) return [];
        return feedbackRes?.data?.[0]?.filter(
            (fb) => fb.targetId === selectedCombo.id,
        );
    }, [feedbackRes, selectedCombo]);

    return (
        <>
            <div className="flex flex-col items-center justify-center">
                <p className="text-gray-600 mt-1 text-2xl text-teal-700 my-4">
                    Premium combos combining comfort and style for a truly exceptional stay.
                </p>
            </div>
            <div className="container mx-auto min-h-screen">
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
                    {listComboFromAPI?.data?.[0].map((combo) => (
                        <Card
                            key={combo.id}
                            hoverable
                            className="rounded-xl shadow-md"
                            bodyStyle={{ padding: "20px" }}
                        >
                            {/* render nội dung 1 card */}
                            <div className='border-gray-200 rounded-xl overflow-hidden'>
                                <div className='border-gray-200 rounded-xl overflow-hidden'>
                                    <Image
                                        width={"100%"}
                                        src="https://cdn.vntrip.vn/cam-nang/wp-content/uploads/2016/12/14524623_1122507874452688_5292429852679961429_o.jpg"
                                    />
                                </div>
                                <h2 className="text-xl font-semibold mb-2 text-teal-600">{combo.name}</h2>

                                <p className="mb-1 text-teal-600">{combo.description}</p>

                                <p className="mb-1">
                                    <span className="font-semibold">Discount:</span> <Tag color="red">{combo.discountValue}%</Tag>
                                </p>

                                <p className="mb-1">
                                    <span className="font-semibold">Max discount amount: </span>
                                    <Tag color="red">{combo.maxDiscountAmount}</Tag>
                                    <Tag color="red">USD</Tag>
                                </p>

                                <p className="mb-1">
                                    <span className="font-semibold">Min stay days: </span>
                                    <Tag color="blue">{combo.minStayNights} days</Tag>
                                </p>
                                <p className="mb-1">
                                    <span className="font-semibold">Room type: </span>
                                    <Tag color="blue">{combo.roomType.name}</Tag>
                                </p>
                            </div>
                            {/* render button của card */}
                            <div className='flex justify-between items-center mt-4 gap-4'>
                                <Button
                                    variant="outline"
                                    size="sm"
                                    className="flex-1 border-teal-600 text-teal-600 hover:bg-teal-50 bg-transparent"
                                    onClick={() => {
                                        setSelectedCombo(combo);
                                        setOpen(true);
                                    }}
                                >
                                    <Eye className="w-4 h-4 mr-2" />
                                    View Details
                                </Button>
                                <Button
                                    size="sm"
                                    className="flex-1 bg-teal-600 hover:bg-teal-700"
                                    onClick={() => {
                                        const accessToken = Cookies.get('accessToken');
                                        if (!accessToken) {
                                            toast.warning('Please log in before booking a combo!');
                                            setTimeout(() => navigate('/login'), 3000);
                                            return;
                                        }
                                        handleBookCombo(combo)
                                    }}
                                >
                                    Book Now
                                </Button>
                            </div>
                        </Card>
                    ))}
                </div>
            </div>
            <Modal
                open={open}
                onCancel={() => setOpen(false)}
                footer={null}
                width={800}
                title={
                    <span className="text-xl font-semibold text-teal-700">
                    {selectedCombo?.name}
                    </span>
                }
            >
                {selectedCombo && (
                    <div className="space-y-4">
                        <p className="text-gray-600">
                            {selectedCombo.description}
                        </p>

                        <Divider />

                        <div className="grid grid-cols-2 gap-4">
                            <p>
                            <strong>Discount:</strong>{" "}
                            <Tag color="red">{selectedCombo.discountValue}%</Tag>
                            </p>

                            <p>
                            <strong>Max discount:</strong>{" "}
                            <Tag color="red">{selectedCombo.maxDiscountAmount} USD</Tag>
                            </p>

                            <p>
                            <strong>Min stay:</strong>{" "}
                            <Tag color="blue">{selectedCombo.minStayNights} days</Tag>
                            </p>

                            <p>
                            <strong>Room type:</strong>{" "}
                            <Tag color="blue">{selectedCombo.roomType?.name}</Tag>
                            </p>
                        </div>

                        <Divider />

                        {/* Services */}
                        <div>
                            <h3 className="text-lg font-semibold text-teal-600 mb-2">
                            Included Services
                            </h3>

                            <div className="space-y-3">
                            {selectedCombo.comboServices?.map((item) => (
                                <div
                                key={item.serviceId}
                                className="border rounded-lg p-3 hover:bg-gray-50"
                                >
                                <p className="font-medium">{item.service.name}</p>
                                <p
                                    className="text-sm text-gray-600"
                                    dangerouslySetInnerHTML={{
                                    __html: item.service.description,
                                    }}
                                />
                                <Tag color="green">{item.service.price} USD</Tag>
                                </div>
                            ))}
                            </div>
                        </div>

                        <Divider />

                        <div className="flex justify-end gap-3">
                            <Button
                            className="bg-teal-600 hover:bg-teal-700"
                            onClick={() => {
                                setOpen(false);
                                handleBookCombo(selectedCombo);
                            }}
                            >
                            Book This Combo
                            </Button>
                        </div>
                        <Divider />

                        <div>
                        <h3 className="text-lg font-semibold text-teal-600 mb-3">
                            Customer Feedback
                        </h3>

                        {loadingFeedbacks ? (
                            <div className="flex justify-center py-6">
                            <Spin />
                            </div>
                        ) : comboFeedbacks.length === 0 ? (
                            <Empty description="No feedback for this combo yet" />
                        ) : (
                            <div className="space-y-4">
                            {comboFeedbacks.map((fb) => (
                                <div
                                key={fb.id}
                                className="border rounded-lg p-4 bg-gray-50"
                                >
                                <div className="flex items-center gap-3 mb-2">
                                    <Avatar src={fb.user.avatar} size={40}>
                                    {fb.user.name?.charAt(0)}
                                    </Avatar>

                                    <div>
                                    <p className="font-medium">{fb.user.name}</p>
                                    <Rate disabled value={fb.rating} />
                                    </div>
                                </div>

                                <p className="text-gray-700">{fb.comment}</p>

                                <p className="text-xs text-gray-400 mt-1">
                                    {new Date(fb.createdAt).toLocaleDateString()}
                                </p>
                                </div>
                            ))}
                            </div>
                        )}
                        </div>

                    </div>
                    
                )}
            </Modal>

        </>
    );
};

export default Combos;