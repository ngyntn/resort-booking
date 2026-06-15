import { Link } from 'react-router';
import { useNavigate } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { userSelector, userAction } from '../../stores/reducers/userReducer';
import Cookies from 'js-cookie';
import { Button } from '@ui/button';
import { Bell, FileText, LogOut, User } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@ui/dropdown-menu';
import { Avatar } from '@ui/avatar';
import { Popover, PopoverContent, PopoverTrigger } from '@ui/popover';
import { ScrollArea } from '@ui/scroll-area';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import bookingApi from '@apis/booking';
import dayjs from 'dayjs';
import { Badge } from '@ui/badge';

const SignIn = () => {
  const isLoggedIn = useSelector(userSelector.isLoggedIn);
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const [isOpen, setIsOpen] = useState(false);
  const user = useSelector(userSelector.selectUser);
  const [notifications, setNotifications] = useState([]);
  const sortedNotifications = useMemo(() => {
    return [...notifications].sort(
      (a, b) => dayjs(b.time, 'HH:mm DD/MM/YYYY').valueOf() - dayjs(a.time, 'HH:mm DD/MM/YYYY').valueOf()
    );
  }, [notifications]);

  const { data: bookingData } = useQuery({
    queryKey: ['bookings', user?.id],
    queryFn: () =>
      bookingApi.getBookings({
        page: 1,
        limit: 1000,
        userId: user?.id,
        status: ['pending'],
      }),
    keepPreviousData: true,
    enabled: !!user?.id,
  });

  const bookings = useMemo(() => bookingData?.data?.data[0] || [], [bookingData]);

  const addRoomUpdatedNotification = useCallback((booking, notifications) => {
    // Kiểm tra có phòng nào thay đổi thông tin không
    function checkBookingForNotification(booking) {
      const bookingCreatedAt = dayjs(booking.createdAt);
      const roomUpdatedAt = dayjs(booking.room.updatedAt);
      return roomUpdatedAt.isAfter(bookingCreatedAt);
    }

    if (notifications.find((n) => n.id === booking.id)) {
      return notifications;
    }

    if (checkBookingForNotification(booking)) {
      notifications.push({
        id: booking.id,
        title: `Room ${booking.room.roomNumber} has been updated`,
        message: `Your booking #${booking.id} starting on ${dayjs(booking.startDate).format(
          'DD/MM'
        )} has been updated. Please check the details.`,
        time: dayjs(booking.room.updatedAt).format('HH:mm DD/MM/YYYY'),
      });
    }

    return notifications;
  }, []);

  const addContractNotification = useCallback((booking, notifications) => {
    if (booking.contract && booking.contract.signedByUser === null) {
      const contractId = `contract-${booking.id}`;
      if (!notifications.find((n) => n.id === contractId)) {
        notifications.push({
          id: contractId,
          title: `Contract for room ${booking.room.roomNumber} needs signing`,
          message: `Your booking #${booking.id} has a contract ready to sign. Please check and sign it.`,
          time: dayjs(booking.contract.createdAt).format('HH:mm DD/MM/YYYY'),
        });
      }
    }
    return notifications;
  }, []);

  useEffect(() => {
    let allNotifications = [];

    bookings.forEach((booking) => {
      allNotifications = addRoomUpdatedNotification(booking, allNotifications);
      allNotifications = addContractNotification(booking, allNotifications);
    });

    // Lưu local thông báo
    localStorage.setItem('notifications', JSON.stringify(allNotifications));
    setNotifications(allNotifications);
  }, [bookings, addRoomUpdatedNotification, addContractNotification]);

  const handleLogout = () => {
    Cookies.remove('accessToken');
    Cookies.remove('refreshToken');
    dispatch(userAction.logout());
    navigate('/');
  };

  return (
    <>
      <div className="hidden md:flex items-center space-x-4 mt-12">
        {isLoggedIn ? (
          <div className="center-both gap-4">
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  data-testid="home-user-dropdown-btn"
                  variant="outline"
                  size="icon"
                  className="rounded-full border border-transparent hover:border-gray-300"
                >
                  <Avatar className="center-both">
                    <User />
                  </Avatar>
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-56">
                <DropdownMenuItem asChild>
                  <Link to="/profile" className="flex items-center">
                    <User className="w-4 h-4 mr-2" />
                    Myself
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link to="/contracts" className="flex items-center">
                    {' '}
                    {/* New link for Contracts */}
                    <FileText className="w-4 h-4 mr-2" />
                    My Contracts
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link to="/booking-history" className="flex items-center">
                    {' '}
                    {/* New link for Favorite Room */}
                    <FileText className="w-4 h-4 mr-2" />
                    Booking History
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={handleLogout} className="text-red-600 focus:text-red-600">
                  <LogOut className="w-4 h-4 mr-2" />
                  Sign Out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        ) : (
          <div className="flex items-center space-x-3">
            <Button asChild
              variant="ghost"
              className="text-gray-700 hover:text-teal-700 border border-teal-200 hover:bg-teal-50"
            >
              <Link data-testid="home-signin-btn" to="/login">Sign In</Link>
            </Button>
            <Button className="bg-teal-600 hover:bg-teal-700">
              <Link to="/signup">Sign Up</Link>
            </Button>
          </div>
        )}
      </div>
    </>
  );
};

export default SignIn;
