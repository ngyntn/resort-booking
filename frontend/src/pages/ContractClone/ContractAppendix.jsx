import React, { useEffect, useState } from 'react'
import dayjs from 'dayjs'

const ContractAppendix = ({ data }) => {
    const [extraServices, setExtraServices] = useState([])
    const checkIn = dayjs(data.startDate);
    const checkOut = dayjs(data.endDate);
    const duration = checkOut.diff(checkIn, 'day') + 1;
    const customerName = data?.user?.name || 'N/A';
    const customerPhone = data?.user?.phone || 'N/A';
    const customerEmail = data?.user?.email || 'N/A';
    const customerCCCD = data?.user?.cccd || 'N/A';

    useEffect(() => {
        if (data?.bookingServices) {
            // Lọc các dịch vụ bổ sung (không qua combo, trạng thái confirmed)
            const filteredServices = data.bookingServices.filter(item =>
                item.isBookedViaCombo === 0 && item.status === 'confirmed'
            );
            setExtraServices(filteredServices);
        }
    }, [data])

    const getServiceDuration = (startDate, endDate) => {
        const start = new Date(startDate);
        const end = new Date(endDate);
        const diff = Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;
        return diff > 0 ? diff : 1;
    };

    const grandTotal = extraServices.reduce((sum, service) => {
        const duration = getServiceDuration(service.startDate, service.endDate);
        const price = Number(service?.service?.price ?? 0);
        const quantity = Number(service?.quantity ?? 0);

        return sum + price * quantity * duration;
    }, 0);

    return (
        <div className="bg-white p-6 md:p-10 max-w-4xl mx-auto shadow-xl rounded-lg border">
            {/* Header Section */}
            <div className="">
                {/* Left Header (Green Blob) */}
                <div className="bg-teal-600 p-6 text-white rounded-br-3xl">
                    <h1 className="text-3xl font-bold mb-2 uppercase">APPENDIX</h1>
                    <p className="text-lg">No. {data.id}</p>
                    <p className="text-lg">Date: {dayjs().format('MMMM DD YYYY')}</p>
                    <p className="text-lg">Contract ID: {data.contract?.bookingId}</p>
                    {/* Corner curve - styling purposes */}
                    <div className="absolute top-0 right-0 w-8 h-8 bg-white" style={{ clipPath: 'polygon(0 0, 100% 0, 0 100%)' }}></div>
                </div>
            </div>

            {/* Bill To & Payment Method Section */}
            <div className="flex justify-between mt-8 pb-4 border-b">
                <div className="w-1/2">
                    <h3 className="text-gray-600 font-semibold mb-2">Details to.</h3>
                    <div className="text-sm space-y-1">
                        <p><strong>Name:</strong> {customerName}</p>
                        <p><strong>Phone:</strong> {customerPhone}</p>
                        <p><strong>Email:</strong> {customerEmail}</p>
                        <p><strong>CCCD:</strong> {customerCCCD}</p>
                    </div>
                </div>

                <div className="w-1/2 text-right">
                    <h3 className="text-gray-600 font-semibold mb-2">Booking Info</h3>
                    <div className="text-sm space-y-1">
                        <p><strong>Room:</strong> {data.roomNumber} ({data.room.type.name})</p>
                        <p><strong>Check-in:</strong> {data.startDate}</p>
                        <p><strong>Check-out:</strong> {data.endDate}</p>
                        <p><strong>Duration:</strong> {duration} days(s)</p>
                    </div>
                </div>
            </div>

            {/* Services Table */}
            <h3 className="text-xl font-bold text-gray-700 mt-6 mb-3">Service Breakdown (person/day)</h3>
            <div className="overflow-x-auto">
                <table className="min-w-full bg-white border border-gray-200">
                    <thead className="bg-teal-500 text-white">
                        <tr>
                            <th className="py-2 px-4 text-left">ITEM DESCRIPTION</th>
                            <th className="py-2 px-4 text-left">QUANTITY</th>
                            <th className="py-2 px-4 text-left">START</th>
                            <th className="py-2 px-4 text-left">END</th>
                            <th className="py-2 px-4 text-left">PRICE</th>
                            <th className="py-2 px-4 text-right">TOTAL</th>
                        </tr>
                    </thead>
                    <tbody>
                        {/* 2. Extra Services Charge */}
                        {extraServices.map((service, index) => (
                            <tr key={service.id} className="border-b hover:bg-gray-50">

                                <td className="py-2 px-4 text-left">{service.service.name}</td>
                                <td className="py-2 px-4 text-left">{service.quantity} guest</td>
                                <td className="py-2 px-4 text-left">{service.startDate}</td>
                                <td className="py-2 px-4 text-left">{service.endDate}</td>
                                <td className="py-2 px-4 text-left">{service.service.price}</td>
                                <td className="py-2 px-4 text-right">
                                    {(() => {
                                        const durationService = getServiceDuration(service.startDate, service.endDate);
                                        const price = Number(service?.service?.price ?? 0);
                                        const quantity = Number(service?.quantity ?? 0);
                                        return `$${(price * quantity * durationService).toFixed(2)}`;
                                    })()}
                                </td>
                            </tr>
                        ))}

                        {/* Total Row */}
                        <tr className="bg-gray-100">
                            <td colSpan={5} className="py-3 px-4 text-right font-semibold">
                                Grand Total:
                            </td>
                            <td className="py-3 px-4 text-right font-bold">
                                ${grandTotal.toFixed(2)}
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

            {/* Thank You & Contact Section */}
            <div className="mt-10 flex justify-between items-end border-t border-gray-300 pt-6">

                {/* Contact Info */}
                <div className="w-1/3">
                    <h3 className="font-bold mb-2">Contact.</h3>
                    <div className="text-sm space-y-1">
                        <p><strong>Phone:</strong> (+84) 123456789</p>
                        <p><strong>Mail:</strong> yasou-resort@mail.com</p>
                        <p><strong>Website:</strong> www.yasuo-resort.com</p>
                    </div>
                </div>

                {/* Thank You Message */}
                <div className="w-2/3 text-right">
                    <h2 className="text-3xl font-black text-gray-800 tracking-wider mb-2">THANK YOU</h2>
                    <p className="text-sm text-gray-500 italic">
                        The contract appendix serves as a detailed breakdown of all agreed services and costs.
                    </p>
                </div>
            </div>

        </div>
    )
}

export default ContractAppendix