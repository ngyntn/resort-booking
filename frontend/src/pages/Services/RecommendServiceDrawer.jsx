import { Drawer, Card, Pagination } from "antd";
import { useState } from "react";
import useFetch from "@src/hooks/fetch.hook";
import apis from "@src/apis";
import ServiceCard from './ServiceCard';

export default function RecommendServiceDrawer() {
    const { data, isLoading } = useFetch(
        () => apis.service.getReCommendServices({ page: 1, limit: 100 }), // Fetch all at once
        [] // Empty dependency array to fetch only once
    );

    const services = data?.data?.[0] || []; // Access the services array

    return (
        <div>
            {isLoading ? (
                <div className="flex justify-center p-4">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-teal-600"></div>
                </div>
            ) : (
                <div className="">
                    {services.map((svc) => (
                        // <div className="mb-4">
                        //     <Card key={svc.id} className="rounded-xl shadow-md h-full">
                        //         <div className="flex justify-between items-center ">

                        //             <h3 className="font-semibold text-lg mb-2">{svc.name}</h3>
                        //             <p className="text-teal-700 font-bold mb-2">${svc.price}</p>
                        //         </div>
                        //         <div
                        //             className="text-gray-700 leading-relaxed"
                        //             dangerouslySetInnerHTML={{ __html: svc.description }}
                        //         />
                        //     </Card>
                        // </div>
                        <ServiceCard key={svc.id} service={svc} />
                    ))}
                </div>
            )}
        </div>
    );
}
