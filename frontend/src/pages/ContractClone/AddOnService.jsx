import React, { useEffect, useState } from 'react'
import { CheckCircle } from 'lucide-react';

const AddOnService = ({ data }) => {
    const [serviceInCombo, setServiceInCombo] = useState([])
    useEffect(() => {
        setServiceInCombo(data.filter(item => item.isBookedViaCombo == 1))
    }, [data])
    return (
        <div id="services-section" className="bg-white p-6 rounded-xl shadow mb-4">
            <h1 className='text-xl mb-2'> Services in combo</h1>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {serviceInCombo.length === 0 ? (
                    <div className="col-span-3 text-center py-8 text-gray-500">
                        No services available
                    </div>
                ) : (
                    serviceInCombo?.map((service) => {
                        return (
                            <div
                                key={service.id}
                                className="p-4 border border-green-500 bg-green-50 rounded-lg"
                            >
                                <div className="flex justify-between items-start">
                                    <div>
                                        <h4 className="font-medium">{service.service.name}</h4>
                                        <p className="text-sm text-gray-600 mt-1 line-clamp-2"
                                            dangerouslySetInnerHTML={{ __html: service.service.description }} />
                                    </div>
                                    <div className="text-right">
                                        <div className="font-medium text-blue-600">
                                            ${service.service.price}
                                        </div>
                                        <div className="flex items-center justify-end">
                                            <span className="text-xs text-green-600 mr-1">Included</span>
                                            <CheckCircle className="h-5 w-5 text-green-500" />
                                        </div>
                                    </div>
                                </div>
                            </div>
                        );
                    })
                )}
            </div>
        </div>
    )
}

export default AddOnService