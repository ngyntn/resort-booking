import React, { useEffect, useState, useMemo } from "react";
import useFetch from "../../hooks/fetch.hook";
import apis from "../../apis/index";
import { useSelector } from "react-redux";
import { userSelector } from "../../stores/reducers/userReducer";
import { Button, Card, Image, Tag, Modal, Form, Rate, Input, Tabs, Tooltip } from "antd";
import { formatCurrencyUSD } from "@libs/utils";
import dayjs from "dayjs";
import {
    CalendarOutlined,
    UserOutlined,
    EuroCircleOutlined,
    ClockCircleOutlined 
} from "@ant-design/icons";
import { toast } from 'react-toastify';
import { useLocation, useNavigate, useParams } from 'react-router';

// hàm tính số ngày giữa 2 ngày (bao gồm cả ngày bắt đầu và kết thúc)
const getNumberOfDays = (startDate, endDate) => {
    const start = dayjs(startDate);
    const end = dayjs(endDate);
    // Total days: (End date - Start date) + 1
    const days = end.diff(start, 'day') + 1;
    return Math.max(0, days);
};

// Hàm tính tổng giá dịch vụ theo công thức: price * quantity * số ngày
const calculateServicePriceTotal = (bookingServices, startDate, endDate) => {
    if (!bookingServices || bookingServices.length === 0) {
        return 0;
    }
    const totalDays = getNumberOfDays(startDate, endDate);
    const confirmedServices = bookingServices.filter(bs => bs.status === "confirmed");
    return confirmedServices.reduce((total, bs) => {
        const price = parseFloat(bs.price || 0);
        const quantity = parseFloat(bs.quantity || 1);
        const serviceCost = price * quantity * totalDays;
        return total + serviceCost;
    }, 0);
};

// --------------------------- MAIN COMPONENT ---------------------------

export default function BookingHistory() {
    const navigate = useNavigate();
    const [isModalVisible, setIsModalVisible] = useState(false);
    const [selectedBooking, setSelectedBooking] = useState(null);
    const [loading, setLoading] = useState(true);
    const [bookings, setBookings] = useState([]);
    const user = useSelector(userSelector.selectUser);

    // Gọi API để lấy dữ liệu bookings, rooms, services, combos
    const { data: bookingsData } = useFetch(() =>
        apis.booking.getBookings({ page: 1, limit: Number.MAX_SAFE_INTEGER })
    );
    const { data: roomsData } = useFetch(() =>
        apis.room.getRooms({ page: 1, limit: Number.MAX_SAFE_INTEGER })
    );
    const { data: servicesData } = useFetch(() =>
        apis.service.getServices({ page: 1, limit: Number.MAX_SAFE_INTEGER })
    );
    const { data: combosData } = useFetch(() =>
        apis.booking.getCombosForAll({ page: 1, limit: Number.MAX_SAFE_INTEGER })
    );

    useEffect(() => {
        if (
            !user ||
            !bookingsData?.data?.[0] ||
            !roomsData?.data?.[0] ||
            !servicesData?.data?.[0]
        ) {
            if (user) setLoading(true);
            return;
        }

        const bookingsList = bookingsData.data[0];
        const roomsList = roomsData.data[0];
        const servicesList = servicesData.data[0];

        const filteredBookings = bookingsList
            .filter(
                (booking) =>
                    booking.userId === user.id &&
                    booking.status === "confirmed" &&
                    dayjs(booking.endDate).isBefore(dayjs(), 'day')
            )
            .sort((a, b) => new Date(b.startDate) - new Date(a.startDate));
        
        console.log('Filtered Bookings:', filteredBookings);

        const combined = filteredBookings.map((booking) => {
            const room = roomsList.find((r) => r.id === booking.roomId) || null;

            // tính toán số ngày
            const numberOfDays = getNumberOfDays(booking.startDate, booking.endDate);
            // Calculate Nights (for room cost, usually Days - 1)
            const numberOfNights = numberOfDays > 0 ? numberOfDays - 1 : 0; 

            // tính toán tổng giá dịch vụ
            const servicePriceTotal = calculateServicePriceTotal(
                booking.bookingServices,
                booking.startDate,
                booking.endDate
            );

            const confirmedBookingServices = booking.bookingServices
                ?.filter(bs => bs.status === "confirmed") || [];

            // logic kiểm tra dịch vụ duy nhất
            const serviceMap = confirmedBookingServices.reduce((acc, bs) => {
                const serviceDetail = servicesList.find((s) => s.id === bs.serviceId);
                
                if (serviceDetail) {
                    if (acc[bs.serviceId]) {
                        // đếm số lượng đã đặt nếu dịch vụ đã tồn tại trong map
                        acc[bs.serviceId].bookedQuantity += parseFloat(bs.quantity || 1);
                    } else {
                        // thêm dịch vụ mới vào map
                        acc[bs.serviceId] = { 
                            ...serviceDetail, 
                            bookedQuantity: parseFloat(bs.quantity || 1), 
                            bookedPrice: parseFloat(bs.price || 0) 
                        };
                    }
                }
                return acc;
            }, {});

            // chuyển đổi map thành mảng dịch vụ duy nhất
            const services = Object.values(serviceMap);

            const roomPricePerNight = parseFloat(booking.roomPrice || 0);
            // Room price is calculated by nights
            const roomPriceTotal = roomPricePerNight * numberOfNights;

            const comboInfo = booking.comboId ? { id: booking.comboId } : null;

            return {
                ...booking,
                room,
                services,
                servicePriceTotal,
                roomPriceTotal,
                numberOfDays, 
                numberOfNights, 
                key: booking.id,
                comboInfo
            };
        });

        setBookings(combined);
        setLoading(false);
    }, [bookingsData, roomsData, servicesData, user]);

    const getNameComboById = (comboId) => {
        if (!combosData?.data?.[0]) return 'N/A';
        const combo = combosData.data[0].find(c => c.id === comboId);
        return combo ? combo.name : 'N/A';
    }

    const showModal = (booking) => {
        setSelectedBooking(booking);
        setIsModalVisible(true);
    };

    const handleCancel = () => {
        setIsModalVisible(false);
    };

    const handleRoomReview = async (values) => {
        try {
            await apis.user.createFeedback({
                bookingId: selectedBooking.id,
                rating: values.roomRating,
                comment: values.roomComment,
                targetType: 'room',
                targetId: selectedBooking.roomId
            });
            toast.success('Room review submitted successfully!');
            // setIsModalVisible(false);
        } catch (error) {
            if (error.response?.data?.error?.code === 'Conflict') {
                toast.warning('You have already reviewed this room');
            } else {
                toast.error('An error occurred while submitting your review');
            }
        }
    };
    const handleServiceReview = async (serviceId, values) => {
        try {
            await apis.user.createFeedback({
                bookingId: selectedBooking.id,
                rating: values.serviceRating,
                comment: values.serviceComment,
                targetType: 'service',
                targetId: serviceId
            });
            toast.success('Service review submitted successfully!');
        } catch (error) {
            if (error.response?.data?.error?.code === 'Conflict') {
                toast.warning('You have already reviewed this service');
            } else {
                toast.error('An error occurred while submitting your service review');
            }
        }
    };
    const handleComboReview = async (values) => {
        try {
            await apis.user.createFeedback({
                bookingId: selectedBooking.id,
                rating: values.comboRating,
                comment: values.comboComment,
                targetType: 'combo',
                targetId: selectedBooking.comboId
            });
            toast.success('Combo review submitted successfully!');
            // setIsModalVisible(false);
        } catch (error) {
            if (error.response?.data?.error?.code === 'Conflict') {
                toast.warning('You have already reviewed this combo');
            } else {
                toast.error('An error occurred while submitting your combo review');
            }
        }
    };

    const handleBookRoom = (room) => {
    navigate(`/booking-confirmation/${room.id}`, {
      state: { room },
    });
  };

    const ServiceReviewForm = ({ service, booking }) => {
        const [form] = Form.useForm();

        const onFinish = (values) => {
            handleServiceReview(service.id, values).then(() => {
                form.resetFields();
            });
        };

        return (
            <div key={service.id} className="p-4 border rounded-lg bg-gray-50 shadow-sm">
                <h4 className="font-semibold text-[#0d584d] mb-3">{service.name}</h4>

                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item
                        name="serviceRating"
                        label={<span className="font-medium">Rating</span>}
                        rules={[{ required: true, message: 'Please select a star rating' }]}
                        initialValue={5}
                    >
                        <Rate allowHalf className="text-xl" />
                    </Form.Item>

                    <Form.Item
                        name="serviceComment"
                        label={<span className="font-medium">Review</span>}
                        rules={[{ required: true, message: 'Please enter your review' }]}
                    >
                        <Input.TextArea
                            rows={3}
                            placeholder={`Write your review for ${service.name}. Share what you liked or disliked.`}
                        />
                    </Form.Item>

                    <div className="text-right mt-4">
                        <Button type="primary" htmlType="submit" className="bg-[#009689] hover:bg-[#007f73] border-none">
                            Submit review
                        </Button>
                    </div>
                </Form>
            </div>
        );
    };

    const BookingCard = ({ booking, showModal }) => {
        // Kiểm tra nếu booking đã hoàn thành (ngày hiện tại sau ngày kết thúc)
        const isCompleted = dayjs(booking.endDate).isBefore(dayjs(), 'day');

        return (
            <Card
                key={booking.id}
                className="shadow-xl border border-gray-100 transition-transform duration-300 hover:scale-[1.02] hover:shadow-2xl"
                cover={
                    <div className="aspect-[4/3] overflow-hidden">
                        <img
                            alt="Room"
                            src={`${import.meta.env.VITE_API_BASE_URL}/${booking.room?.media?.[0]?.path}`}
                            className="w-full h-full object-cover transition-transform duration-500 hover:scale-110"
                            preview={false}
                        />
                    </div>
                }
            >
                <div className="space-y-4">
                    {/* Header: Room Name & Status */}
                    <div className="flex justify-between items-start border-b pb-3 border-gray-100">
                        <h3 className="text-xl font-bold text-gray-800 leading-tight">
                            {booking.room?.roomNumber} - {booking.room?.type?.name}
                        </h3>
                        <div className="flex flex-col">
                            {booking.comboId && (
                                <Tag color="purple" className="m-0 text-sm py-1 px-3 mb-1">
                                    Combo
                                </Tag>
                            )}
                            <Tag color={isCompleted ? "green" : "blue"} className="m-0 text-sm py-1 px-3">
                                {isCompleted ? "Completed" : "Confirmed"}
                            </Tag>
                        </div>
                    </div>

                    {/* Basic Info */}
                    <div className="text-gray-600 space-y-2">
                        <div className="flex items-center">
                            <span className="font-medium">Contract ID:</span> 
                            <span className="ml-2">{booking.id}</span>
                        </div>
                        <div className="flex items-center text-sm">
                            <CalendarOutlined className="mr-3 text-[#0d584d]" />
                            <span className="font-medium">Dates:</span>
                            <span className="ml-2">
                                {dayjs(booking.startDate).format('DD/MM/YYYY')} -{' '}
                                {dayjs(booking.endDate).format('DD/MM/YYYY')}
                            </span>
                        </div>
                        <div className="flex items-center text-sm">
                            <ClockCircleOutlined className="mr-3 text-[#0d584d]" />
                            <span className="font-medium">Duration:</span>
                            <span className="ml-2 font-bold text-base">{booking.numberOfDays} Days</span>
                        </div>
                        <div className="flex items-center text-sm">
                            <UserOutlined className="mr-3 text-[#0d584d]" />
                            <span className="font-medium">Guests:</span>
                            <span className="ml-2 font-bold text-base">{booking.capacity}</span>
                        </div>
                    </div>

                    {/* Grand Total - Simplified */}
                    <div className="pt-3 border-t border-dashed border-gray-200 space-y-1">
                        
                        {/* ONLY Grand Total, based on total price in contract */}
                        <div className="flex justify-between items-center pt-2">
                            <div className="flex flex-col">
                                <div className="flex items-center text-lg font-bold text-[#0d584d]">
                                    <EuroCircleOutlined className="mr-2" /> Grand Total:
                                </div>
                                <span className="text-xs text-gray-500 mt-1">
                                    (Visit the contract page for more details)
                                </span>
                            </div>
                            <span className="text-xl font-extrabold text-[#009689]">
                                {formatCurrencyUSD(booking.totalPrice)}
                            </span>
                        </div>
                    </div>

                    {/* Services Tags */}
                    {booking.services?.length > 0 && (
                        <div className="pt-3 border-t border-gray-100">
                            <div className="text-sm font-medium text-gray-500 mb-2">Included Services:</div>
                            <div className="flex flex-wrap gap-2">
                                {booking.services.map((service) => (
                                    <Tooltip
                                        key={service.id}
                                        title={`${service.name} (x${service.bookedQuantity} at ${formatCurrencyUSD(service.bookedPrice)}/day)`}
                                    >
                                        <Tag color="blue" className="text-sm py-0.5 px-2 cursor-help">
                                            {service.name}
                                        </Tag>
                                    </Tooltip>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* Review Button */}
                    <div className="flex justify-between items-center mt-4">
                        <Button
                            type="primary"
                            className="mt-4 bg-[#009689] hover:bg-[#007f73] border-none text-white transition-colors duration-300"
                            size="large"
                            onClick={() => showModal(booking)}
                            disabled={!isCompleted}
                        >
                            {isCompleted ? "Review Experience" : "Review (After Stay)"}
                        </Button>
                        <Button
                            ype="primary"
                            className="mt-4 bg-[#009689] hover:bg-[#007f73] border-none text-white transition-colors duration-300"
                            size="large"
                            onClick={handleBookRoom.bind(this, booking.room)}
                        >
                            Book Again
                        </Button>
                    </div>
                </div>
            </Card>
        );
    };

    return (
        <>
            <div className="mx-auto px-4 sm:px-6 lg:px-8 py-10 bg-gray-50 min-h-screen">
                <div className="max-w-7xl mx-auto">
                    <h2 className="text-3xl font-extrabold mb-8 text-[#0d584d] border-b-2 border-gray-200 pb-2">
                        Booking History
                    </h2>

                    {loading ? (
                        <div className="flex justify-center items-center h-64">
                            <div className="animate-spin rounded-full h-16 w-16 border-t-4 border-b-4 border-[#0d584d]"></div>
                        </div>
                    ) : bookings.length === 0 ? (
                        <div className="text-center py-20 bg-white rounded-lg shadow-sm text-gray-500 text-lg border">
                            <img
                                src="https://via.placeholder.com/150/f0f4f8?text=No+Bookings"
                                alt="No bookings"
                                className="mx-auto mb-4 opacity-50"
                            />
                            You do not have any confirmed booking history.
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 gap-8">
                            {bookings.map((booking) => (
                                <BookingCard key={booking.id} booking={booking} showModal={showModal} />
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* ----------- Review Modal ----------- */}
            <Modal
                title={<div className="text-2xl font-bold text-[#0d584d]">Share Your Experience</div>}
                open={isModalVisible}
                onCancel={handleCancel}
                footer={null}
                width={selectedBooking?.services?.length > 0 || selectedBooking?.comboId ? 900 : 600}
                className="review-modal"
            >
                {selectedBooking && (
                    <Tabs
                        defaultActiveKey="room"
                        type="card"
                        size="large"
                        className="mt-4"
                        items={[
                            {
                                key: 'room',
                                label: 'Room',
                                children: (
                                    <Form onFinish={handleRoomReview} layout="vertical" initialValues={{ roomRating: 5 }}>
                                        <div className="text-lg font-semibold mb-4">{selectedBooking.room?.roomNumber} - {selectedBooking.room?.type?.name}</div>
                                        <Form.Item
                                            name="roomRating"
                                            label={<span className="font-medium">Room Rating</span>}
                                            rules={[{ required: true, message: 'Please select a star rating' }]}
                                        >
                                            <Rate allowHalf className="text-2xl" />
                                        </Form.Item>

                                        <Form.Item
                                            name="roomComment"
                                            label={<span className="font-medium">Room Review</span>}
                                            rules={[{ required: true, message: 'Please enter your review' }]}
                                        >
                                            <Input.TextArea rows={6} placeholder="How was your stay in this room? Share your thoughts on cleanliness, comfort, and view." />
                                        </Form.Item>

                                        <div className="flex justify-end gap-2 pt-4 border-t border-gray-100 mt-4">
                                            <Button onClick={handleCancel}>Cancel</Button>
                                            <Button type="primary" htmlType="submit" className="bg-[#009689] hover:bg-[#007f73] border-none">Submit Room Review</Button>
                                        </div>
                                    </Form>
                                )
                            },
                            ...(selectedBooking.services?.length > 0
                                ? [{
                                    key: 'services',
                                    label: `Services (${selectedBooking.services.length})`,
                                    children: (
                                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-h-[60vh] overflow-y-auto pr-2">
                                            {selectedBooking.services.map(service => (
                                                <ServiceReviewForm
                                                    key={service.id}
                                                    service={service}
                                                    booking={selectedBooking}
                                                />
                                            ))}
                                        </div>
                                    )
                                }]
                                : []),

                            ...(selectedBooking.comboInfo
                                ? [{
                                    key: 'combo',
                                    label: 'Combo',
                                    children: (
                                        <Form onFinish={handleComboReview} layout="vertical" initialValues={{ comboRating: 5 }}>
                                            <div className="text-lg font-semibold mb-4">Combo Name: {getNameComboById(selectedBooking.comboId)}&nbsp;-&nbsp;ID: {selectedBooking.comboId}</div> 
                                            <Form.Item
                                                name="comboRating"
                                                label={<span className="font-medium">Combo Rating</span>}
                                                rules={[{ required: true, message: 'Please select a star rating' }]}
                                            >
                                                <Rate allowHalf className="text-2xl" />
                                            </Form.Item>

                                            <Form.Item
                                                name="comboComment"
                                                label={<span className="font-medium">Combo Review</span>}
                                                rules={[{ required: true, message: 'Please enter your review' }]}
                                            >
                                                <Input.TextArea
                                                    rows={6}
                                                    placeholder="Share your overall experience with the booking combo (e.g., value, arrangement, overall quality)."
                                                />
                                            </Form.Item>

                                            <div className="flex justify-end gap-2 pt-4 border-t border-gray-100 mt-4">
                                                <Button onClick={handleCancel}>Cancel</Button>
                                                <Button type="primary" htmlType="submit" className="bg-[#009689] hover:bg-[#007f73] border-none">Submit Combo Review</Button>
                                            </div>
                                        </Form>
                                    )
                                }]
                                : [])
                        ]}
                    />
                )}
            </Modal>
        </>
    );
}
