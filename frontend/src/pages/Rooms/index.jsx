import { useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import roomApi from '@apis/room';
import roomTypeApi from '@apis/room-type';
import serviceApi from '@apis/service';
import userApi from '@apis/user';
import { Eye, MapPin, Users, Heart } from 'lucide-react';
import { AnimatePresence, motion } from 'framer-motion';
import { Card, CardContent } from '@ui/card';
import { Badge } from '@ui/badge';
import { Button } from '@ui/button';
import { useNavigate } from 'react-router';
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationLink,
  PaginationNext,
  PaginationPrevious,
} from '@ui/pagination';
import { formatCurrencyUSD } from '@libs/utils';
import { useScrollDown } from '@src/hooks/useScrollDown';
import { FilterCard } from './FilterCard';
import { RoomDetailDialog } from './RoomDetailDialog';
import { useDispatch, useSelector } from 'react-redux';
import { roomTypeActions, roomTypeSelector } from '@src/stores/reducers/roomTypeReducer';
import { serviceActions, serviceSelector } from '@src/stores/reducers/serviceReducer';
import dayjs from 'dayjs';
import { toast } from 'react-toastify';
import Cookies from 'js-cookie';
import RecommendRoomList from './RecommendRoomList';

const baseUrl = import.meta.env.VITE_API_BASE_URL;

const RoomPage = () => {
  useScrollDown('#rooms');
  const dispatch = useDispatch();
  const navigate = useNavigate();

  const [filterState, setFilterState] = useState({
    keyword: '',
    maxPeople: '',
    typeId: '',
    priceRange: {
      minPrice: '',
      maxPrice: '',
    },
    dateRange: {
      startDate: dayjs().add(1, 'day').format('YYYY-MM-DD'),
      endDate: '',
    },
  });

  const [selectedRoom, setSelectedRoom] = useState(null);
  const [selectedFavoriteRoom, setSelectedFavoriteRoom] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const limit = 4;

  // Get danh sách loại phòng
  const roomTypes = useSelector(roomTypeSelector.selectAll);

  useEffect(() => {
    const fetchRoomTypes = async () => {
      try {
        const res = await roomTypeApi.getRoomTypes({ page: 1, limit: 1000 });
        const data = res?.data?.data?.[0] ?? [];
        dispatch(roomTypeActions.setRoomTypes(data));
      } catch (err) {
        console.error('Failed to fetch room types:', err);
      }
    };

    if (roomTypes.length === 0) fetchRoomTypes();
  }, [dispatch, roomTypes.length]);

  // Get danh sách dịch vụ
  const services = useSelector(serviceSelector.selectAll);

  useEffect(() => {
    const fetchServices = async () => {
      try {
        const res = await serviceApi.getServices({ page: 1, limit: 1000 });
        const data = res?.data?.data?.[0] ?? [];
        dispatch(serviceActions.setServices(data));
      } catch (err) {
        console.error('Failed to fetch room types:', err);
      }
    };

    if (services.length === 0) fetchServices();
  }, [dispatch, services.length]);

  const { data: roomData, isLoading } = useQuery({
    queryKey: ['rooms', filterState, currentPage],
    queryFn: () => {
      const params = {
        page: currentPage,
        limit,
        ...(filterState.keyword && { keyword: filterState.keyword }),
        ...(filterState.maxPeople && { maxPeople: +filterState.maxPeople }),
        ...(filterState.typeId && { typeId: +filterState.typeId }),
      };

      const { minPrice, maxPrice } = filterState.priceRange;
      if (minPrice !== '' || maxPrice !== '') {
        params.priceRange = {};
        if (minPrice !== '') params.priceRange.minPrice = +minPrice;
        if (maxPrice !== '') params.priceRange.maxPrice = +maxPrice;
      }

      const { startDate, endDate } = filterState.dateRange;
      if (startDate && endDate) {
        params.dateRange = { startDate, endDate };
      }

      console.log(params);
      return roomApi.getRooms(params);
    },
    keepPreviousData: true,
  });

  const rooms = roomData?.data?.data[0] ?? [];
  const totalPages = Math.ceil((roomData?.data?.data[1] || 1) / limit);

  // Read access token from cookies for display/use in this page
  const accessToken = Cookies.get('accessToken') || null;

  const onHandleSelectFavoriteRoom = async (id) => {
    try {
      await userApi.createFavoriteRoom({ roomId: id });
      toast.success('Added to favorites');
    } catch (err) {
      console.error('Create favorite failed', err);
      toast.error('Room had been added to favorites');
    }
  }
  const handlePageChange = (pageNumber) => {
    setCurrentPage(pageNumber);
  };

  const handleApplyFilters = () => {
    setCurrentPage(1);
  };

  const handleClearFilters = () => {
    setFilterState({
      keyword: '',
      maxPeople: '',
      typeId: '',
      priceRange: {
        minPrice: '',
        maxPrice: '',
      },
      dateRange: {
        startDate: '',
        endDate: '',
      },
    });
    setCurrentPage(1);
  };

  const fadeInUp = {
    initial: { y: 40, opacity: 0 },
    animate: { y: 0, opacity: 1 },
    transition: { duration: 0.5 },
  };

  const handleBookRoom = (room) => {
    navigate(`/booking-confirmation/${room.id}`, {
      state: { room, startDate: filterState.dateRange.startDate, endDate: filterState.dateRange.endDate },
    });
  };

  return (
    <section id="rooms" className="min-h-screen py-8">
      <AnimatePresence mode="wait">
        <div className="container mx-auto">
          {/* Filters Section (Always visible, now in a column) */}
          <aside className="mb-2">
            <FilterCard
              filterState={filterState}
              setFilterState={setFilterState}
              handleApplyFilters={handleApplyFilters}
              handleClearFilters={handleClearFilters}
              roomTypes={roomTypes}
              className="shadow-sm"
            />
          </aside>

          {/* Results Section */}
          <div className='grid grid-cols-1 md:grid-cols-3 gap-6'>

            <div className="md:col-span-2">
              <h1 className='text-xl font-bold text-gray-800 mb-2 mt-2 border-b'>Room available</h1>
              {isLoading ? (
                <></>
              ) : rooms.length === 0 ? (
                <motion.div className="text-center py-16" {...fadeInUp}>
                  <div className="text-gray-400 mb-4">
                    <MapPin className="w-16 h-16 mx-auto" />
                  </div>
                  <h3 className="text-xl font-semibold text-gray-600 mb-2">No rooms found</h3>
                  <p className="text-gray-500">Please try again with different search terms or filters</p>
                </motion.div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {rooms.map((room, index) => (
                    <motion.div key={room.id} {...fadeInUp} transition={{ delay: index * 0.2 }}>
                      <Card className="flex flex-col overflow-hidden hover:shadow-xl transition-all duration-300 group h-full bg-white">
                        <div className="relative">
                          <img
                            src={`${baseUrl}/${room.media[0]?.path || 'placeholder.svg'}`}
                            alt={`Room ${room.roomNumber}`}
                            className="w-full h-48 object-cover group-hover:scale-105 transition-transform duration-300"
                            onError={(e) => {
                              e.target.onerror = null; // tránh loop vô hạn
                              e.target.src = '/placeholder.svg';
                            }}
                          />
                          <div className="absolute top-3 left-3">
                            <Badge className="bg-teal-600 hover:bg-teal-600 text-white">Room {room.roomNumber}</Badge>
                          </div>
                          <div className="absolute top-3 right-3">
                            <Badge variant="secondary" className="bg-white/90 text-gray-700">
                              {room.type.name}
                            </Badge>
                          </div>
                        </div>

                        <CardContent className="p-4 flex-1 flex flex-col">
                          <h3 className="text-xl font-bold text-gray-800 mb-3">
                            {room.type.name} - Room {room.roomNumber}
                          </h3>
                          <div
                            className="text-sm text-gray-600 line-clamp-2 flex-1"
                            dangerouslySetInnerHTML={{ __html: room.description }}
                          ></div>

                          <div className="flex items-center gap-4 mb-4 text-sm text-gray-600">
                            <div className="flex items-center gap-1">
                              <Users className="w-4 h-4 text-teal-600" />
                              <span>{room.maxPeople} Guests</span>
                            </div>
                          </div>

                          <div className="text-2xl font-bold text-teal-600 mb-4 flex justify-between items-center">
                            <span>
                              {formatCurrencyUSD(room.price)}/day
                            </span>
                            <div>
                              <Button
                                variant="outline"
                                size="sm"
                                className="flex-1 border-red-400 text-red-400 hover:bg-red-50 bg-transparent"
                                onClick={() => onHandleSelectFavoriteRoom(room.id)}
                              >
                                <Heart className="w-4 h-4 mr-2" />
                                Add to favorites
                              </Button>
                            </div>
                          </div>
                          <div className="flex gap-2">
                            <Button
                              variant="outline"
                              size="sm"
                              className="flex-1 border-teal-600 text-teal-600 hover:bg-teal-50 bg-transparent"
                              onClick={() => setSelectedRoom(room)}
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
                                  toast.warning('Please log in before booking a room!');
                                  setTimeout(() => navigate('/login'), 3000);
                                  return;
                                }
                                handleBookRoom(room);
                              }}
                            >
                              Book Room
                            </Button>
                          </div>
                        </CardContent>
                      </Card>
                    </motion.div>
                  ))}
                </div>
              )}
              {/* Pagination Controls */}
              {totalPages > 1 && (
                <Pagination className="mt-8">
                  <PaginationContent>
                    <PaginationItem>
                      <PaginationPrevious
                        href="#"
                        onClick={(e) => {
                          e.preventDefault();
                          if (currentPage > 1) handlePageChange(currentPage - 1);
                        }}
                        className={currentPage === 1 ? 'pointer-events-none opacity-50' : ''}
                      />
                    </PaginationItem>
                    {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
                      <PaginationItem key={page}>
                        <PaginationLink
                          href="#"
                          isActive={page === currentPage}
                          onClick={(e) => {
                            e.preventDefault();
                            handlePageChange(page);
                          }}
                        >
                          {page}
                        </PaginationLink>
                      </PaginationItem>
                    ))}
                    <PaginationItem>
                      <PaginationNext
                        href="#"
                        onClick={(e) => {
                          e.preventDefault();
                          if (currentPage < totalPages) handlePageChange(currentPage + 1);
                        }}
                        className={currentPage === totalPages ? 'pointer-events-none opacity-50' : ''}
                      />
                    </PaginationItem>
                  </PaginationContent>
                </Pagination>
              )}
            </div>
            <div className='md:col-span-1'>
              <h1 className='text-xl font-bold text-gray-800 mb-2 mt-2 border-b'>Recommend Room</h1>
              <div className='h-[calc(100vh-100px)] overflow-y-auto scroll-thin'>
                <RecommendRoomList />
              </div>
            </div>
          </div>
        </div>
      </AnimatePresence>
      {/* Room Detail Modal */}
      {!!selectedRoom && (
        <RoomDetailDialog
          selectedRoom={selectedRoom}
          setSelectedRoom={setSelectedRoom}
          handleBookRoom={handleBookRoom}
          comboList={[]}
        />
      )}
    </section>
  );
};

export default RoomPage;
