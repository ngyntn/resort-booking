import React, { useRef, useState, useEffect } from 'react'
import { Card, Button, Modal, Tooltip } from 'antd'
import { PlusOutlined } from '@ant-design/icons';
import SignaturePad from 'signature_pad';
import { toast } from 'react-toastify';
import ContractServices from './ContractServices'
import useFetch from '@src/hooks/fetch.hook'
import apis from '@apis/index'
import { CheckCircle } from 'lucide-react';
import ContractRoomImg from './ContractRoomImg'
import { useNavigate } from 'react-router-dom';

import dayjs from 'dayjs';
import ContractRoomchange from './ContractRoomchange';
import AddOnService from './AddOnService';
import ContractAppendix from './ContractAppendix';

const baseUrl = import.meta.env.VITE_API_BASE_URL

const ContractWithStatus = ({ status, data }) => {

    const navigate = useNavigate();

    const [filteredBookings, setFilteredBookings] = useState([])
    const { data: listComboFromAPI } = useFetch(() => apis.booking.getCombosForAll({ page: 1, limit: 1000 }))
    const [isSignModalOpen, setIsSignModalOpen] = useState(false);
    const [currentContract, setCurrentContract] = useState(null);
    const [showInvoiceModal, setShowInvoiceModal] = useState(false);
    const [invoiceUrl, setInvoiceUrl] = useState('');
    const [signaturePad, setSignaturePad] = useState(null);
    const [isSigning, setIsSigning] = useState(false);
    const [showReceiptModal, setShowReceiptModal] = useState(false);
    const [receiptUrl, setReceiptUrl] = useState('');
    const [openAppendix, setOpenAppendix] = useState(false);
    const [selectedAppendixData, setSelectedAppendixData] = useState([]);
    const [receiptStatus, setReceiptStatus] = useState({});
    const [isLoadingReceiptStatus, setIsLoadingReceiptStatus] = useState(true);
    const signatureCanvas = useRef(null);

    useEffect(() => {
        if (data && Array.isArray(data)) {
            const filtered = data.filter((item) => {
                return item.status === status
            })
            setFilteredBookings(filtered)
        }
    }, [data, status])

    useEffect(() => {
        return () => {
            if (signaturePad) {
                signaturePad.off();
            }
        };
    }, [signaturePad]);

    useEffect(() => {
        if (!filteredBookings || filteredBookings.length === 0) {
            setIsLoadingReceiptStatus(false);
            return;
        }

        setIsLoadingReceiptStatus(true); // Bắt đầu tải

        const checkReceipts = async () => {
            const statusMap = {};

            // Dùng Promise.all để gọi API song song, tối ưu tốc độ
            const promises = filteredBookings.map(item =>
                checkInvoice(item.id).then(hasReceipt => ({ id: item.id, hasReceipt }))
            );

            const results = await Promise.all(promises);

            results.forEach(result => {
                statusMap[result.id] = result.hasReceipt;
            });

            setReceiptStatus(statusMap);
            setIsLoadingReceiptStatus(false); // Kết thúc tải
        };

        checkReceipts();

    }, [filteredBookings]);

    if (!data) {
        return <div>Loading...</div>
    }

    if (filteredBookings.length === 0) {
        return (
            <div className="p-4 text-gray-500 h-[600px]">
                No {status} bookings found.
                <div className="text-sm">(Total bookings: {data.length}, Statuses: {[...new Set(data.map(b => b.status))].join(', ')})</div>
            </div>
        )
    }

    const handleSignContract = (contract) => {
        setCurrentContract(contract);
        setIsSignModalOpen(true);

        // Initialize signature pad when modal opens
        setTimeout(() => {
            if (signatureCanvas.current) {
                const canvas = signatureCanvas.current;
                canvas.width = canvas.offsetWidth;
                canvas.height = 200;

                const pad = new SignaturePad(canvas, {
                    backgroundColor: 'rgb(255, 255, 255)',
                    penColor: 'rgb(0, 0, 0)'
                });

                setSignaturePad(pad);
            }
        }, 0);
    };
    const handleCancelSign = () => {
        setIsSignModalOpen(false);
        setCurrentContract(null);
        if (signaturePad) {
            signaturePad.clear();
        }
    };

    const handleSaveSignature = async () => {
        if (!signaturePad || signaturePad.isEmpty()) {
            toast.error('Vui lòng ký vào hợp đồng');
            return;
        }

        setIsSigning(true);
        try {
            // 1. Convert signature to blob
            const signatureData = signaturePad.toDataURL('image/png');
            const blob = await fetch(signatureData).then(res => res.blob());

            // 2. Create FormData and append the signature
            const formData = new FormData();
            formData.append('file', blob, 'signature.png');

            // 3. Upload the signature
            const uploadResponse = await apis.upload.uploadFile(formData);
            if (!uploadResponse.data) {
                throw new Error('Upload failed');
            }

            // 4. Save the contract with the signature URL
            await apis.booking.userSignTheContract({
                param: { bookingId: currentContract.bookingId },
                body: { signatureUrl: uploadResponse.data.path } // Adjust this based on your API response
            });

            toast.success('Ký hợp đồng thành công');
            setIsSignModalOpen(false);
            window.location.reload(); // Refresh to show updated contract status
        } catch (error) {
            console.error('Error signing contract:', error);
            toast.error(error.response?.data?.error?.message || 'Có lỗi xảy ra khi ký hợp đồng');
        } finally {
            setIsSigning(false);
        }
    };

    const renderSignModal = () => (
        <Modal
            title="Ký hợp đồng"
            open={isSignModalOpen}
            onCancel={handleCancelSign}
            footer={[
                <Button key="cancel" onClick={handleCancelSign}>
                    Hủy
                </Button>,
                <Button
                    key="clear"
                    onClick={() => signaturePad && signaturePad.clear()}
                >
                    Xóa chữ ký
                </Button>,
                <Button
                    key="submit"
                    type="primary"
                    onClick={handleSaveSignature}
                    loading={isSigning}
                    className="bg-blue-500 hover:bg-blue-600"
                >
                    Xác nhận
                </Button>,
            ]}
            width={800}
        >
            <div className="border rounded p-4">
                <p className="mb-4">Vui lòng ký vào khung dưới đây:</p>
                <div className="border rounded bg-white">
                    <canvas
                        ref={signatureCanvas}
                        className="w-full h-[200px]"
                    />
                </div>
                <p className="mt-2 text-sm text-gray-500">
                    Ký tên của bạn vào khung trên
                </p>
            </div>
        </Modal>
    );

    const handleCancelBooking = async (booking) => {
        try {
            await apis.booking.cancelBooking({
                param: { bookingId: booking.id }
            });
            toast.success('Đã hủy đặt phòng thành công');
            window.location.reload(); // Refresh to update the UI
        } catch (error) {
            console.error('Error cancelling booking:', error);
            toast.error(error.response?.data?.message || 'Có lỗi xảy ra khi hủy đặt phòng');
        }
    };

    const handleDepositPayment = async (booking) => {
        if (!booking?.id) {
            toast.error('Không tìm thấy thông tin đặt phòng');
            return;
        }

        try {
            const response = await apis.booking.paymentContract({
                bookingId: booking.id,
                paymentStage: 'deposit_payment',
                bankCode: 'VNBANK'
            });

            if (response?.data?.data) {
                window.location.href = response.data.data;
            }
            toast.info('Redirecting to payment page...');
        } catch (error) {
            console.error('Lỗi khi tạo thanh toán:', error);
            toast.error(error.response?.data?.error?.message || 'Something went wrong when creating payment');
        }
    };

    const handleFinalPayment = async (booking) => {
        try {
            const response = await apis.booking.paymentContract({
                bookingId: booking,
                paymentStage: 'final_payment',
                bankCode: 'VNBANK'
            });

            if (response?.data?.data) {
                window.location.href = response.data.data;
            }
            toast.info('Redirecting to payment page...');
        } catch (error) {
            console.error('Lỗi khi tạo thanh toán:', error);
            toast.error(error.response?.data?.error?.message || 'Something went wrong when creating payment');
        }
    };

    const handleShowInvoice = async (bookingId) => {
        try {
            const response = await apis.booking.getInvoice(bookingId);
            const invoiceUrls = response.data.data; // Array of invoice URLs

            if (invoiceUrls && invoiceUrls.length > 0) {
                // Clean up the URL
                let url = invoiceUrls[0]
                    .replace(/\\/g, '/')
                    .replace(/^\.\//, '')
                    .replace(/^http:\/\/?/i, '')
                    .replace(/^https:\/\/?/i, '')
                    .replace(/^[^/]+\//, '');

                const baseUrl = 'http://localhost:8080';
                const fullUrl = `${baseUrl}/${url.replace(/^\//, '')}`;

                setInvoiceUrl(fullUrl);
                setShowInvoiceModal(true);
            } else {
                toast.info('No invoice found, please wait until checkout Date and make the rest payment first');
            }
        } catch (error) {
            toast.error(error.response?.data?.message || 'Something went wrong when fetching invoice');
        }
    };

    const handleShowRecepeit = async (bookingId) => {
        try {
            const response = await apis.booking.getReceipt(bookingId);
            const receiptUrls = response.data.data; // Array of receipt URLs

            if (receiptUrls && receiptUrls.length > 0) {
                // Clean up the URL
                let url = receiptUrls[0]
                    .replace(/\\/g, '/')  // Convert backslashes to forward slashes
                    .replace(/^\.\//, '') // Remove leading ./
                    .replace(/^http:\/\/?/i, '') // Remove any existing http:// (case insensitive)
                    .replace(/^https:\/\/?/i, '') // Remove any existing https:// (case insensitive)
                    .replace(/^[^/]+\//, ''); // Remove any existing domain part

                // Add the correct protocol and host
                const baseUrl = 'http://localhost:8080'; // Always use the backend URL directly

                // Construct the full URL
                const fullUrl = `${baseUrl}/${url.replace(/^\//, '')}`;

                setReceiptUrl(fullUrl);
                setShowReceiptModal(true);
            } else {
                toast.info('Not receipt found, please make the payment deposit first');
            }
        } catch (error) {
            toast.error(error.response?.data?.error?.message || 'Something went wrong when fetching receipt');
        }
    }

    // show phụ lục hợp đồng
    const handleShowAppendix = (data) => {
        setSelectedAppendixData(data);
        setOpenAppendix(true);
    };
    const handleCloseAppendix = () => {
        setOpenAppendix(false);
        setSelectedAppendixData([]);
    };
    const checkInvoice = async (bookingId) => {
        try {
            const response = await apis.booking.getReceipt(bookingId);
            if (response?.data?.data.length > 0) {
                return true
            } else {
                return false
            }
        } catch (error) {
            console.error('Lỗi khi kiểm tra biên lai:', error);
            return false;
        }
    }

    return (
        <>
            {filteredBookings.map((item) => (
                <div key={`booking-${item.id}`} className='mb-4'>
                    <Card>
                        <div className="flex justify-between pb-3 border-b">
                            <p className='text-teal-600 text-sm'>Customer Name: <span className="text-gray-600">{item.user.name}</span></p>
                            <p className='text-teal-600 text-sm'>Phone: <span className="text-gray-600">{item.user.phone}</span></p>
                            <p className='text-teal-600 text-sm'>Email: <span className="text-gray-600">{item.user.email}</span></p>
                            <p className='text-teal-600 text-sm'>Citizen Identity Card: <span className="text-gray-600">{item.user.cccd}</span></p>
                        </div>
                        <div className=''>
                            {/* lí do từ chỗi */}
                            {item.reasonForRejection && (
                                <div className="bg-amber-50 border-l-4 border-amber-400 p-4 mb-4 rounded">
                                    <div className="flex items-center">
                                        <svg className="h-5 w-5 text-amber-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                                            <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                                        </svg>
                                        {item.reasonForRejection && (
                                            <div
                                                dangerouslySetInnerHTML={{ __html: item.reasonForRejection }}
                                            />
                                        )}
                                    </div>
                                </div>
                            )}
                            {/* tu dong huy qua 24h */}
                            {item.status === "rejected" && !item.reasonForRejection && (
                                <div className="bg-amber-50 border-l-4 border-amber-400 p-4 mb-4 rounded">
                                    <div className="flex items-center">
                                        <svg className="h-5 w-5 text-amber-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                                            <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                                        </svg>
                                        <div>Your booking has been automatically cancelled after 24 hours of pending status.</div>
                                    </div>
                                </div>
                            )}
                            {item.status === "confirmed" && dayjs().isAfter(dayjs(item.endDate), 'day') && (
                                <div className="bg-amber-50 border-l-4 border-amber-400 p-4 mb-4 rounded">
                                    <div className="flex items-center">
                                        <svg className="h-5 w-5 text-amber-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                                            <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                                        </svg>
                                        <div>Contract ended, thank you. Hope to see you later.</div>
                                    </div>
                                </div>
                            )}
                            <div className='grid grid-cols-12 gap-4'>
                                {/* ảnh phòng */}
                                <div className='col-span-4 mt-4'>
                                    <ContractRoomImg data={item.roomId} />
                                </div>

                                {/* thông tin phòng */}
                                <div className='col-span-6'>
                                    <h1 className="font-semibold mb-3 mt-2 text-xl border-b border-gray-300">Room info&nbsp;-&nbsp;
                                        <span className='text-gray-500'>contract - {item.id}</span>
                                    </h1>
                                    <div className='flex justify-between'>
                                        <div className=''>
                                            <p className='text-teal-600 text-xl'>Room Number: <span className="text-gray-600">{item.roomNumber}</span></p>
                                            <p className='text-teal-600 text-xl'>Room Type: <span className="text-gray-600">{item.room.type.name}</span></p> {/* THÔNG TIN MỚI */}
                                            <p className='text-teal-600 text-xl'>Max People in Room: <span className="text-gray-600">{item.room.maxPeople}</span></p> {/* THÔNG TIN MỚI */}
                                            <p className='text-teal-600 text-xl'>Room Price: <span className="text-gray-600">${item.roomPrice}</span></p>
                                        </div>
                                        <div className=''>
                                            <p className='text-teal-600 text-xl'>Check-in Date: <span className="text-gray-600">{item.startDate}</span></p>
                                            <p className='text-teal-600 text-xl'>Check-out Date: <span className="text-gray-600">{item.endDate}</span></p>
                                            <p className='text-teal-600 text-xl'>Number of people: <span className="text-gray-600">{item.capacity}</span></p>
                                            <p className='text-teal-600 text-xl'>Total Price: <span className="text-gray-600">${item.totalPrice}</span></p>
                                        </div>
                                    </div>
                                </div>

                            </div>
                            <div></div>
                            {/* thao tác hợp đồng */}
                            <div className='mt-2'>
                                {item.contract ? (
                                    <>
                                        <a
                                            href={`${import.meta.env.VITE_API_BASE_URL || ''}/${item.contract.contractUrl}`}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            className="!bg-teal-500 !hover:bg-blue-600 !text-white px-4 py-2 rounded text-sm"
                                        >
                                            View Contract
                                        </a>
                                        {item.status === 'pending' && !item.contract.signedByUser && (
                                            <Button
                                                type="primary"
                                                className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded text-sm ml-2"
                                                onClick={() => handleSignContract(item.contract)}
                                            >
                                                Sign Contract
                                            </Button>
                                        )}
                                        
                                        {item.status === 'pending' && (
                                            <Button
                                                type="primary"
                                                className="ml-2"
                                                onClick={() => handleDepositPayment(item)}
                                            >
                                                Pay deposit
                                            </Button>
                                        )}
                                        {item.status === 'confirmed' && (
                                            <Button
                                                type="primary"
                                                className="ml-2"
                                                onClick={() => handleShowRecepeit(item.id)}
                                            >
                                                Show Receipt
                                            </Button>
                                        )}
                                        {item.status === 'confirmed' && dayjs().isSame(dayjs(item.endDate), 'day') && (
                                            <Button
                                                type="primary"
                                                className="mt-2 ml-2"
                                                onClick={() => handleFinalPayment(item.id)}
                                            >
                                                Full payment
                                            </Button>
                                        )}
                                        {item.status === 'confirmed' && (
                                            <Button
                                                type="primary"
                                                className="mt-2 ml-2"
                                                onClick={() => handleShowInvoice(item.id)}
                                            >
                                                Show invoice
                                            </Button>
                                        )}
                                        {/* && dayjs().isSame(dayjs(item.endDate), 'day') ||
                                            dayjs().isAfter(dayjs(item.endDate), 'day') */}
                                        {item.status === 'confirmed'  && (
                                            <Button
                                                type="primary"
                                                className="bg-teal-500 hover:bg-blue-600 !text-white px-4 py-2 rounded text-sm ml-2"
                                                onClick={() => handleShowAppendix(item)}
                                            >
                                                Show Appendix
                                            </Button>
                                        )}
                                        {item.status === 'pending' && (
                                            <Button
                                                type="primary"
                                                danger
                                                className="ml-2"
                                                onClick={() => handleCancelBooking(item)}
                                            >
                                                Cancel Booking
                                            </Button>
                                        )}
                                    </>
                                ) : (
                                    <>
                                        <span className="text-gray-500 text-xl">No contract available</span>
                                        {item.status === 'pending' && (
                                            <Button
                                                type="primary"
                                                danger
                                                className="ml-2"
                                                onClick={() => handleCancelBooking(item)}
                                            >
                                                Cancel Booking
                                            </Button>
                                        )}
                                    </>
                                )}
                            </div>
                        </div>

                        {/* hiển thị dịch vụ đặt thêm */}
                        <div className=''>
                            <div className='mt-2 w-full'>
                                <AddOnService data={item.bookingServices} />
                                <div className='flex items-center justify-between'>
                                    <h3 className="font-semibold mt-3 text-xl">Additional services</h3>
                                    {(item.status === 'pending' || item.status === 'confirmed') &&
                                        new Date() < new Date(item.endDate) && (
                                            <Tooltip placement="left" title="">
                                                {/* đặt thêm dịch vụ */}
                                                <span className='font-bold text-[17px] text-teal-700 mr-2'>Add more service here {`--->>>`}</span>
                                                <button
                                                    aria-label="Đặt dịch vụ"
                                                    className="inline-flex items-center justify-center h-9 w-9 
                                                    rounded-full bg-teal-500 text-white hover:bg-blue-600 shadow-sm 
                                                    ring-1 ring-inset ring-blue-500/20 hover:ring-blue-500/40 transition-colors 
                                                    animate-pulse hover:animate-none"
                                                    onClick={() => navigate('/services', { state: { bookingId: item.id } })}
                                                >
                                                    <PlusOutlined />
                                                </button>
                                            </Tooltip>
                                        )}
                                </div>
                                <ContractServices data={item.bookingServices} dataCombo={item} />
                            </div>
                        </div>

                        {/* lịch sử đổi phòng */}
                        <div className='col-span-8'>
                            <ContractRoomchange data={item.roomChangeHistories} />
                        </div>
                    </Card>
                </div>
            ))}
            {renderSignModal()}

            {/* biên lai */}
            {showReceiptModal && (
                <div className="fixed inset-0 bg-black/30 backdrop-blur-[1px] flex items-center justify-center z-50 p-4">
                    <div className="bg-white rounded-lg w-full max-w-4xl h-[80vh] flex flex-col">
                        <div className="flex justify-between items-center p-4 border-b">
                            <h3 className="text-lg font-semibold">Biên lai thanh toán</h3>
                            <button
                                onClick={() => setShowReceiptModal(false)}
                                className="text-gray-500 hover:text-gray-700"
                            >
                                ✕
                            </button>
                        </div>
                        <div className="flex-1">
                            <iframe
                                src={`${receiptUrl}#view=fitH`}
                                className="w-full h-full border-0"
                                title="Biên lai thanh toán"
                                type="application/pdf"
                            />
                        </div>
                    </div>
                </div>
            )}
            {/* hóa đơn */}
            {showInvoiceModal && (
                <div className="fixed inset-0 bg-black/30 backdrop-blur-[1px] flex items-center justify-center z-50 p-4">
                    <div className="bg-white rounded-lg w-full max-w-4xl h-[80vh] flex flex-col">
                        <div className="flex justify-between items-center p-4 border-b">
                            <h3 className="text-lg font-semibold">Hóa đơn thanh toán</h3>
                            <button
                                onClick={() => setShowInvoiceModal(false)}
                                className="text-gray-500 hover:text-gray-700"
                            >
                                ✕
                            </button>
                        </div>
                        <div className="flex-1">
                            <iframe
                                src={`${invoiceUrl}#view=fitH`}
                                className="w-full h-full border-0"
                                title="Hóa đơn thanh toán"
                            />
                        </div>
                    </div>
                </div>
            )}
            {/* phụ lục hợp đồng */}
            <Modal
                title="Contract Appendix"
                open={openAppendix}
                onCancel={handleCloseAppendix}
                footer={null}
                width={1000}
            >
                <ContractAppendix data={selectedAppendixData} />
            </Modal>
        </>
    )
}

export default ContractWithStatus