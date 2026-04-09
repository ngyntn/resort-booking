import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { BookingService } from './booking.service';
import { BookingRoomReqDto } from './dtos/booking-room.dto';
import { Booking } from './entities/booking.entity';
import * as moment from 'moment';
import * as fs from 'fs/promises';
import * as ejs from 'ejs';
import * as path from 'path';
import * as puppeteerUtil from 'utils/puppeteer.util';
import * as sharpUtil from 'utils/sharp.util';

describe('BookingService', () => {
  let service: BookingService;
  let mockBookingRepository: any;
  let mockBookingServiceRepository: any;
  let mockDataSource: any;
  let mockQueryRunner: any;
  let mockQueryBuilder: any;

  const fixedNow = new Date('2026-01-01T00:00:00Z');

  beforeAll(() => {
    jest.useFakeTimers().setSystemTime(fixedNow);
  });

  afterAll(() => {
    jest.useRealTimers();
  });

  let mockMailService: any;
  let mockConfigService: any;

  beforeEach(() => {
    mockBookingRepository = {
      create: jest.fn((entity) => ({ ...entity })),
    };

    mockBookingServiceRepository = {};

    mockMailService = {
      bookingRejectNotify: jest.fn().mockResolvedValue(undefined),
    };
    mockConfigService = {
      getServerConfig: jest.fn().mockReturnValue({ frontendUrl: 'http://localhost' }),
    };

    mockQueryBuilder = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(null),
    };

    mockQueryRunner = {
      connect: jest.fn().mockResolvedValue(undefined),
      startTransaction: jest.fn().mockResolvedValue(undefined),
      commitTransaction: jest.fn().mockResolvedValue(undefined),
      rollbackTransaction: jest.fn().mockResolvedValue(undefined),
      release: jest.fn().mockResolvedValue(undefined),
      manager: {
        findOne: jest.fn(),
        create: jest.fn((entity, data) => ({ ...data })),
        save: jest.fn(),
        update: jest.fn(),
        createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
      },
    };

    mockDataSource = {
      createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
      manager: {
        findOne: jest.fn(),
      },
    };

    jest.spyOn(fs, 'readFile').mockResolvedValue(Buffer.from('signature'));
    jest.spyOn(fs, 'writeFile').mockResolvedValue(undefined);
    jest.spyOn(fs, 'unlink').mockResolvedValue(undefined);
    jest.spyOn(ejs, 'renderFile').mockResolvedValue('<html></html>');
    jest.spyOn(puppeteerUtil, 'htmlToPdf').mockResolvedValue(undefined);

    service = new BookingService(
      mockBookingRepository,
      mockBookingServiceRepository,
      mockDataSource as any,
      mockMailService,
      mockConfigService,
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  const userId = 10;
  const roomInfo = {
    id: 1,
    roomNumber: '101A',
    maxPeople: 4,
    price: '150.00',
    status: 'active',
    typeId: 1,
  };

  describe('TC09 - Gửi yêu cầu đặt phòng hợp lệ', () => {
    it('should create pending booking and calculate totalPrice correctly', async () => {
      const payload = {
        roomId: 1,
        startDate: '2026-01-03',
        endDate: '2026-01-05',
        capacity: 2,
      } as BookingRoomReqDto;

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity.name === 'Room') {
          return Promise.resolve(roomInfo);
        }
        return Promise.resolve(null);
      });

      const expectedBooking = {
        userId,
        roomId: payload.roomId,
        roomNumber: roomInfo.roomNumber,
        capacity: payload.capacity,
        roomPrice: roomInfo.price,
        startDate: payload.startDate,
        endDate: payload.endDate,
        status: 'pending',
        createdAt: fixedNow,
        totalPrice: '450.00',
      };

      mockQueryRunner.manager.save.mockResolvedValue(expectedBooking);
      mockQueryBuilder.getOne.mockResolvedValue(null);

      const result = await service.bookingRoom(userId, payload);

      expect(mockDataSource.createQueryRunner).toHaveBeenCalled();
      expect(mockQueryRunner.connect).toHaveBeenCalled();
      expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.findOne).toHaveBeenCalledWith(expect.anything(), {
        where: {
          id: payload.roomId,
        },
        relations: ['type'],
      });
      expect(mockQueryRunner.manager.createQueryBuilder).toHaveBeenCalledWith(expect.anything(), 'booking');
      expect(mockQueryBuilder.getOne).toHaveBeenCalled();
      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(expect.objectContaining({
        userId,
        roomId: payload.roomId,
        capacity: payload.capacity,
        status: 'pending',
        totalPrice: expectedBooking.totalPrice,
      }));
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(result).toEqual(expectedBooking);
    });
  });

  describe('TC10 - Đặt phòng vào ngày quá khứ', () => {
    it('should throw BadRequestException when startDate is in the past', async () => {
      const payload = {
        roomId: 1,
        startDate: '2025-12-31',
        endDate: '2026-01-05',
        capacity: 2,
      } as BookingRoomReqDto;

      await expect(service.bookingRoom(userId, payload)).rejects.toThrow(BadRequestException);
      await expect(service.bookingRoom(userId, payload)).rejects.toMatchObject({
        response: expect.objectContaining({
          message: 'The contract signing date and end date must be in the future',
        }),
      });
    });
  });

  describe('TC11 - Ngày trả phòng trước ngày nhận phòng', () => {
    it('should throw BadRequestException when endDate is before startDate', async () => {
      const payload = {
        roomId: 1,
        startDate: '2026-01-05',
        endDate: '2026-01-03',
        capacity: 2,
      } as BookingRoomReqDto;

      await expect(service.bookingRoom(userId, payload)).rejects.toThrow(BadRequestException);
      await expect(service.bookingRoom(userId, payload)).rejects.toMatchObject({
        response: expect.objectContaining({
          message: 'The contract end date must be later than the signing date',
        }),
      });
    });
  });

  describe('TC12 - Số người vượt quá sức chứa', () => {
    it('should throw BadRequestException when capacity exceeds room maxPeople', async () => {
      const payload = {
        roomId: 1,
        startDate: '2026-01-03',
        endDate: '2026-01-05',
        capacity: 5,
      } as BookingRoomReqDto;

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity.name === 'Room') {
          return Promise.resolve(roomInfo);
        }
        return Promise.resolve(null);
      });

      await expect(service.bookingRoom(userId, payload)).rejects.toThrow(BadRequestException);
      await expect(service.bookingRoom(userId, payload)).rejects.toMatchObject({
        response: expect.objectContaining({
          message: 'No more than 4 people are allowed',
        }),
      });
    });
  });

  describe('TC13 - Đặt phòng đã có người đặt trong ngày đó', () => {
    it('should throw ConflictException when a booking already overlaps', async () => {
      const payload = {
        roomId: 1,
        startDate: '2026-01-03',
        endDate: '2026-01-05',
        capacity: 2,
      } as BookingRoomReqDto;

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity.name === 'Room') {
          return Promise.resolve(roomInfo);
        }
        return Promise.resolve(null);
      });

      mockQueryBuilder.getOne.mockResolvedValue({ id: 100, roomId: 1 });

      await expect(service.bookingRoom(userId, payload)).rejects.toThrow(ConflictException);
      await expect(service.bookingRoom(userId, payload)).rejects.toMatchObject({
        response: expect.objectContaining({
          message: 'This room has already been booked during this time period',
        }),
      });
    });
  });

  describe('TC14 - Đặt phòng đang bảo trì', () => {
    it('should throw ConflictException when room status is maintenance', async () => {
      const maintenanceRoom = {
        ...roomInfo,
        status: 'maintenance',
      };
      const payload = {
        roomId: 1,
        startDate: '2026-01-03',
        endDate: '2026-01-05',
        capacity: 2,
      } as BookingRoomReqDto;

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity.name === 'Room') {
          return Promise.resolve(maintenanceRoom);
        }
        return Promise.resolve(null);
      });

      await expect(service.bookingRoom(userId, payload)).rejects.toThrow(ConflictException);
      await expect(service.bookingRoom(userId, payload)).rejects.toMatchObject({
        response: expect.objectContaining({
          message: 'This room is currently not available for booking',
        }),
      });
    });
  });

  describe('TC15 - Admin từ chối phòng với lý do', () => {
    it('should reject pending booking and reject booking services while sending notification email', async () => {
      const bookingId = 123;
      const reason = 'Hết phòng';
      const booking = {
        id: bookingId,
        status: 'pending',
        contract: null,
        bookingServices: [
          {
            id: 11,
            status: 'pending',
            quantity: 1,
            price: '50.00',
          },
        ],
        user: {
          email: 'customer@example.com',
        },
        startDate: '2026-01-03',
        endDate: '2026-01-05',
        createdAt: fixedNow,
      };

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity.name === 'Booking') {
          return Promise.resolve(booking);
        }
        return Promise.resolve(null);
      });
      mockQueryRunner.manager.update.mockResolvedValue({ affected: 1 });
      mockQueryRunner.manager.save.mockResolvedValue([
        {
          ...booking.bookingServices[0],
          status: 'rejected',
        },
      ]);

      const result = await service.rejectRoomBooking(bookingId, reason);

      expect(mockQueryRunner.manager.update).toHaveBeenCalledWith(
        expect.anything(),
        { id: bookingId },
        {
          status: 'rejected',
          reasonForRejection: reason,
        },
      );
      expect(mockQueryRunner.manager.save).toHaveBeenCalled();
      expect(mockMailService.bookingRejectNotify).toHaveBeenCalledWith(
        booking.user.email,
        expect.objectContaining({
          reasonForRejection: reason,
        }),
      );
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(result).toEqual({ affected: 1 });
    });
  });

  describe('TC17 - Từ chối phòng đã confirmed', () => {
    it('should throw ForbiddenException when booking status is confirmed', async () => {
      const bookingId = 124;
      const booking = {
        id: bookingId,
        status: 'confirmed',
        contract: null,
        bookingServices: [],
        user: {
          email: 'customer@example.com',
        },
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.rejectRoomBooking(bookingId, 'Hết phòng')).rejects.toThrow(ForbiddenException);
      await expect(service.rejectRoomBooking(bookingId, 'Hết phòng')).rejects.toMatchObject({
        message: 'Cannot reject a confirmed booking',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC18 - Chấp nhận phòng (Tạo hợp đồng)', () => {
    it('should create contract html/pdf and save contract record for pending booking', async () => {
      const bookingId = 200;
      const booking = {
        id: bookingId,
        status: 'pending',
        contract: null,
        room: {
          roomNumber: '101A',
          type: { name: 'Deluxe' },
        },
        user: {
          id: 10,
          name: 'Nguyen Van A',
          email: 'customer@example.com',
          dob: '1990-01-01',
          identityIssuedAt: '2010-01-01',
        },
        bookingServices: [
          {
            id: 1,
            status: 'pending',
            createdAt: fixedNow,
            price: '50.00',
            quantity: 1,
            startDate: '2026-01-03',
            endDate: '2026-01-04',
            service: {
              price: '50.00',
            },
          },
        ],
        roomChangeHistories: [],
        startDate: '2026-01-03',
        endDate: '2026-01-04',
        createdAt: fixedNow,
      };

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity.name === 'Booking') {
          return Promise.resolve(booking);
        }
        if (entity.name === 'Contract') {
          return Promise.resolve(null);
        }
        return Promise.resolve(null);
      });
      mockQueryRunner.manager.save.mockResolvedValue({
        id: 1,
        bookingId,
        signedByAdmin: 'admin-signature',
        contractUrl: 'uploads/200_NguyenVanA_Contract.pdf',
      });

      const result = await service.createContract(bookingId);

      expect(ejs.renderFile).toHaveBeenCalled();
      expect(fs.writeFile).toHaveBeenCalled();
      expect(puppeteerUtil.htmlToPdf).toHaveBeenCalled();
      expect(fs.unlink).toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(result).toEqual({
        id: 1,
        bookingId,
        contractUrl: 'uploads/200_NguyenVanA_Contract.pdf',
      });
    });
  });

  describe('TC33 - Dịch vụ bổ sung với startDate ngoài khoảng ngày đặt phòng', () => {
    it('should throw BadRequestException when attachedService startDate is outside booking period', async () => {
      const payload: Partial<BookingRoomReqDto> = {
        roomId: 1,
        startDate: '2026-02-01',
        endDate: '2026-02-05',
        capacity: 2,
        attachedService: [
          {
            id: 1,
            quantity: 1,
            startDate: '2026-01-25', // Trước startDate của booking
            endDate: '2026-01-30',
          },
        ],
      };

      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toThrow(BadRequestException);
      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toMatchObject({
        response: {
          message: 'Start date must be within the booking period',
        },
      });
    });
  });

  describe('TC34 - Dịch vụ bổ sung với ID không tồn tại trong DB', () => {
    it('should throw BadRequestException when service ID does not exist', async () => {
      const payload: Partial<BookingRoomReqDto> = {
        roomId: 1,
        startDate: '2026-02-01',
        endDate: '2026-02-05',
        capacity: 2,
        attachedService: [
          {
            id: 9999, // Service không tồn tại
            quantity: 1,
            startDate: '2026-02-01',
            endDate: '2026-02-05',
          },
        ],
      };

      mockDataSource.manager.findOne.mockResolvedValue(null); // Service không tồn tại

      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toThrow(BadRequestException);
      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toMatchObject({
        response: {
          message: expect.stringContaining('Invalid service ID'),
        },
      });
    });
  });

  describe('TC35 - Dịch vụ bổ sung hợp lệ', () => {
    it('should successfully calculate totalPrice including attachedService', async () => {
      const payload: Partial<BookingRoomReqDto> = {
        roomId: 1,
        startDate: '2026-02-01',
        endDate: '2026-02-05', // 5 ngày
        capacity: 2,
        attachedService: [
          {
            id: 1,
            quantity: 2,
            startDate: '2026-02-01',
            endDate: '2026-02-03', // 3 ngày
          },
        ],
      };

      const room = {
        id: 1,
        roomNumber: '101A',
        maxPeople: 4,
        price: '100.00',
        status: 'active',
        type: { minPrice: '100.00', maxPrice: '150.00' },
      };

      const serviceEntity = { id: 1, price: '50.00', status: 'active' };

      mockDataSource.manager.findOne.mockResolvedValue(serviceEntity);

      mockQueryRunner.manager.findOne.mockResolvedValue(room);
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(null),
      });

      mockQueryRunner.manager.create.mockImplementation((entity, data) => data);
      mockQueryRunner.manager.save.mockResolvedValue({
        id: 1,
        totalPrice: '700.00',
      });

      const result = await service.bookingRoom(1, payload as BookingRoomReqDto);

      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.save).toHaveBeenCalled();
    });
  });

  // Nhóm 2: Combo
  describe('TC36 - Combo với tổng số ngày thuê nhỏ hơn minStayNights', () => {
    it('should throw BadRequestException when rental days is less than combo minStayNights', async () => {
      const payload: Partial<BookingRoomReqDto> = {
        roomId: 1,
        startDate: '2026-02-01',
        endDate: '2026-02-02', // 2 ngày
        capacity: 2,
        comboId: 1,
      };

      const room = {
        id: 1,
        maxPeople: 4,
        price: '100.00',
        status: 'active',
        typeId: 1,
        type: { minPrice: '100.00', maxPrice: '150.00' },
      };

      const combo = {
        id: 1,
        minStayNights: 5,
        roomTypeId: 1,
        isActive: 1,
      };

      mockDataSource.manager.findOne.mockResolvedValue(combo);
      mockQueryRunner.manager.findOne.mockResolvedValue(room);
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(null),
      });

      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toThrow(BadRequestException);
      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toMatchObject({
        response: {
          message: expect.stringContaining('minimum stay'),
        },
      });
    });
  });

  describe('TC37 - Combo hợp lệ với đủ ngày thuê', () => {
    it('should successfully calculate totalPrice with combo discount and services', async () => {
      const payload: Partial<BookingRoomReqDto> = {
        roomId: 1,
        startDate: '2026-02-01',
        endDate: '2026-02-05', // 5 ngày
        capacity: 2,
        comboId: 1,
      };

      const room = {
        id: 1,
        roomNumber: '101A',
        maxPeople: 4,
        price: '100.00',
        status: 'active',
        typeId: 1,
        type: { minPrice: '100.00', maxPrice: '150.00' },
      };

      const combo = {
        id: 1,
        minStayNights: 3,
        roomTypeId: 1,
        isActive: 1,
        discountValue: '10',
        maxDiscountAmount: '100.00',
        comboServices: [
          {
            serviceId: 1,
            service: { id: 1, price: '25.00' },
          },
        ],
      };

      mockDataSource.manager.findOne.mockResolvedValue(combo);
      mockQueryRunner.manager.findOne.mockResolvedValue(room);
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(null),
      });

      mockQueryRunner.manager.create.mockImplementation((entity, data) => data);
      mockQueryRunner.manager.save.mockResolvedValue({ id: 1 });

      const result = await service.bookingRoom(1, payload as BookingRoomReqDto);

      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.save).toHaveBeenCalled();
    });
  });

  // Nhóm 3: Voucher
  describe('TC38 - Voucher với ID không tồn tại hoặc đã sử dụng', () => {
    it('should throw BadRequestException when userVoucher does not exist or is already used', async () => {
      const payload: Partial<BookingRoomReqDto> = {
        roomId: 1,
        startDate: '2026-02-01',
        endDate: '2026-02-05',
        capacity: 2,
        userVoucherId: 9999,
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(null);

      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toThrow(BadRequestException);
      await expect(service.bookingRoom(1, payload as BookingRoomReqDto)).rejects.toMatchObject({
        response: {
          message: 'Invalid user voucher ID',
        },
      });
    });
  });

  describe('TC39 - Voucher hợp lệ (loại % discount)', () => {
    it('should successfully apply percentage discount voucher and mark as used', async () => {
      const payload: Partial<BookingRoomReqDto> = {
        roomId: 1,
        startDate: '2026-02-01',
        endDate: '2026-02-05',
        capacity: 2,
        userVoucherId: 1,
      };

      const room = {
        id: 1,
        roomNumber: '101A',
        maxPeople: 4,
        price: '100.00',
        status: 'active',
        type: { minPrice: '100.00', maxPrice: '150.00' },
      };

      const userVoucher = {
        id: 1,
        userId: 1,
        dateUsed: null,
        voucher: {
          discountType: 'percentage',
          discountValue: '10',
          maxDiscountAmount: '50.00',
        },
      };

      mockDataSource.manager.findOne.mockImplementation((entity: any, options?: any) => {
        if (entity.name === 'UserVoucher') {
          return Promise.resolve(userVoucher);
        }
        return Promise.resolve(null);
      });

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options?: any) => {
        if (entity.name === 'Room') return Promise.resolve(room);
        if (entity.name === 'UserVoucher') return Promise.resolve(userVoucher);
        return Promise.resolve(null);
      });

      mockQueryRunner.manager.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(null),
      });

      mockQueryRunner.manager.create.mockImplementation((entity, data) => data);
      mockQueryRunner.manager.save.mockResolvedValue({ id: 1 });
      mockQueryRunner.manager.update.mockResolvedValue({ affected: 1 });

      const result = await service.bookingRoom(1, payload as BookingRoomReqDto);

      expect(mockQueryRunner.manager.update).toHaveBeenCalledWith(
        expect.objectContaining({ name: 'UserVoucher' }),
        expect.anything(),
        expect.objectContaining({ dateUsed: fixedNow }),
      );
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
    });
  });

  // Nhóm 4: rejectRoomBooking edge cases
  describe('TC40 - Từ chối booking đã cancelled', () => {
    it('should throw ForbiddenException when booking status is cancelled', async () => {
      const bookingId = 100;
      const booking = {
        id: bookingId,
        status: 'cancelled',
        contract: null,
        bookingServices: [],
        user: { email: 'user@example.com' },
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.rejectRoomBooking(bookingId, 'Some reason')).rejects.toThrow(ForbiddenException);
      await expect(service.rejectRoomBooking(bookingId, 'Some reason')).rejects.toMatchObject({
        message: 'Cannot reject a cancelled booking',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC41 - Từ chối booking với bookingId không tồn tại', () => {
    it('should throw ForbiddenException when booking does not exist', async () => {
      const bookingId = 9999;

      mockQueryRunner.manager.findOne.mockResolvedValue(null);

      await expect(service.rejectRoomBooking(bookingId, 'Some reason')).rejects.toThrow(ForbiddenException);
      await expect(service.rejectRoomBooking(bookingId, 'Some reason')).rejects.toMatchObject({
        message: 'You are not allowed to modify this resource',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  // Nhóm 5: createContract edge cases
  describe('TC42 - Tạo hợp đồng cho booking không tồn tại', () => {
    it('should throw BadRequestException when booking does not exist', async () => {
      const bookingId = 9999;

      mockQueryRunner.manager.findOne.mockResolvedValue(null);

      await expect(service.createContract(bookingId)).rejects.toThrow(BadRequestException);
      await expect(service.createContract(bookingId)).rejects.toMatchObject({
        response: {
          message: 'Invalid booking ID param',
        },
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC43 - Tạo hợp đồng cho booking bị rejected', () => {
    it('should throw ConflictException when booking status is rejected', async () => {
      const bookingId = 100;
      const booking = {
        id: bookingId,
        status: 'rejected',
        contract: null,
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.createContract(bookingId)).rejects.toThrow(ConflictException);
      await expect(service.createContract(bookingId)).rejects.toMatchObject({
        message: 'Cannot create contract for a rejected booking',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC44 - Hợp đồng đã tồn tại cho booking này', () => {
    it('should throw ConflictException when contract already exists for booking', async () => {
      const bookingId = 100;
      const booking = {
        id: bookingId,
        status: 'pending',
        contract: { id: 1 },
      };

      mockQueryRunner.manager.findOne.mockImplementation((entity: any) => {
        if (entity.name === 'Booking') return Promise.resolve(booking);
        if (entity.name === 'Contract') return Promise.resolve({ id: 1 }); // Contract đã tồn tại
        return Promise.resolve(null);
      });

      await expect(service.createContract(bookingId)).rejects.toThrow(ConflictException);
      await expect(service.createContract(bookingId)).rejects.toMatchObject({
        message: 'Contract already exists for this booking',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  // ============ THÊM TEST CHO cancelRoomBooking ============
  describe('TC45 - Huỷ booking đang pending', () => {
    it('should successfully cancel pending booking and cancel booking services', async () => {
      const userId = 10;
      const bookingId = 300;
      const booking = {
        id: bookingId,
        userId,
        status: 'pending',
        bookingServices: [
          { id: 1, status: 'pending' },
          { id: 2, status: 'pending' },
        ],
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);
      mockQueryRunner.manager.update.mockResolvedValue({ affected: 1 });
      mockQueryRunner.manager.save.mockResolvedValue([
        { ...booking.bookingServices[0], status: 'cancelled' },
        { ...booking.bookingServices[1], status: 'cancelled' },
      ]);

      const result = await service.cancelRoomBooking(userId, bookingId);

      expect(mockQueryRunner.manager.update).toHaveBeenCalledWith(
        expect.anything(),
        { id: bookingId },
        { status: 'cancelled' },
      );
      expect(mockQueryRunner.manager.save).toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(result).toEqual({ affected: 1 });
    });
  });

  describe('TC46 - Huỷ booking pending không có services', () => {
    it('should cancel pending booking without services', async () => {
      const userId = 10;
      const bookingId = 301;
      const booking = {
        id: bookingId,
        userId,
        status: 'pending',
        bookingServices: [],
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);
      mockQueryRunner.manager.update.mockResolvedValue({ affected: 1 });

      const result = await service.cancelRoomBooking(userId, bookingId);

      expect(mockQueryRunner.manager.save).not.toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(result).toEqual({ affected: 1 });
    });
  });

  describe('TC47 - Huỷ booking đã confirmed', () => {
    it('should throw ForbiddenException when cancelling confirmed booking', async () => {
      const userId = 10;
      const bookingId = 302;
      const booking = {
        id: bookingId,
        userId,
        status: 'confirmed',
        bookingServices: [],
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toThrow(ForbiddenException);
      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toMatchObject({
        message: 'Cannot cancel a confirmed booking',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC48 - Huỷ booking đã rejected', () => {
    it('should throw ForbiddenException when cancelling rejected booking', async () => {
      const userId = 10;
      const bookingId = 303;
      const booking = {
        id: bookingId,
        userId,
        status: 'rejected',
        bookingServices: [],
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toThrow(ForbiddenException);
      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toMatchObject({
        message: 'Cannot cancel a rejected booking',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC49 - Huỷ booking đã cancelled', () => {
    it('should throw BadRequestException when booking is already cancelled', async () => {
      const userId = 10;
      const bookingId = 304;
      const booking = {
        id: bookingId,
        userId,
        status: 'cancelled',
        bookingServices: [],
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toThrow(BadRequestException);
      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toMatchObject({
        response: {
          message: 'This booking has already been cancelled',
        },
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC50 - Huỷ booking không tồn tại', () => {
    it('should throw ForbiddenException when booking does not exist', async () => {
      const userId = 10;
      const bookingId = 9999;

      mockQueryRunner.manager.findOne.mockResolvedValue(null);

      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toThrow(ForbiddenException);
      await expect(service.cancelRoomBooking(userId, bookingId)).rejects.toMatchObject({
        message: 'You are not allowed to modify this resource',
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  // ============ THÊM TEST CHO rejectRoomBooking EDGE CASE ============
  describe('TC51 - Từ chối booking đã rejected', () => {
    it('should throw BadRequestException when booking is already rejected', async () => {
      const bookingId = 400;
      const booking = {
        id: bookingId,
        status: 'rejected',
        contract: null,
        bookingServices: [],
        user: { email: 'user@example.com' },
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.rejectRoomBooking(bookingId, 'Reason')).rejects.toThrow(BadRequestException);
      await expect(service.rejectRoomBooking(bookingId, 'Reason')).rejects.toMatchObject({
        response: {
          message: 'This booking has already been rejected',
        },
      });
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  // ============ THÊM TEST CHO signContract ============
  describe('TC52 - Ký hợp đồng thành công', () => {
    it('should successfully sign contract by user', async () => {
      const userId = 10;
      const bookingId = 500;
      const signatureUrl = 'uploads/signature.png';

      const booking = {
        id: bookingId,
        userId,
        status: 'pending',
        contract: { id: 1, signedByUser: null },
        room: { type: { name: 'Deluxe Room' } },
        user: { name: 'John Doe' },
        bookingServices: [],
        roomChangeHistories: [],
        payments: [
          {
            status: 'success',
            gatewayResponse: JSON.stringify({ vnp_OrderInfo: 'DP-500-10' }),
          },
        ],
      };

      jest.spyOn(fs, 'access').mockResolvedValue(undefined as any);
      jest.spyOn(sharpUtil, 'hasSignature').mockResolvedValue(true);
      jest.spyOn(fs, 'writeFile').mockResolvedValue(undefined as any);
      jest.spyOn(puppeteerUtil, 'htmlToPdf').mockResolvedValue(undefined);

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity.name === 'Booking') return Promise.resolve(booking);
        return Promise.resolve(null);
      });

      mockQueryRunner.manager.update.mockResolvedValue({ affected: 1 });

      const result = await service.signContract(userId, bookingId, signatureUrl);

      expect(mockQueryRunner.manager.update).toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
    });
  });

  describe('TC53 - Ký hợp đồng - booking không tồn tại', () => {
    it('should throw BadRequestException when booking does not exist', async () => {
      const userId = 10;
      const bookingId = 9999;
      const signatureUrl = 'uploads/signature.png';

      jest.spyOn(fs, 'access').mockResolvedValue(undefined as any);
      jest.spyOn(sharpUtil, 'hasSignature').mockResolvedValue(true);
      jest.spyOn(fs, 'unlink').mockResolvedValue(undefined as any);

      mockQueryRunner.manager.findOne.mockResolvedValue(null);

      await expect(service.signContract(userId, bookingId, signatureUrl)).rejects.toThrow(BadRequestException);
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC54 - Ký hợp đồng - hợp đồng không tồn tại', () => {
    it('should throw NotFoundException when contract does not exist', async () => {
      const userId = 10;
      const bookingId = 501;
      const signatureUrl = 'uploads/signature.png';

      const booking = {
        id: bookingId,
        userId,
        status: 'pending',
        contract: null,
        room: { type: {} },
        user: {},
        bookingServices: [],
        roomChangeHistories: [],
        payments: [],
      };

      jest.spyOn(fs, 'access').mockResolvedValue(undefined as any);
      jest.spyOn(sharpUtil, 'hasSignature').mockResolvedValue(true);
      jest.spyOn(fs, 'unlink').mockResolvedValue(undefined as any);

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.signContract(userId, bookingId, signatureUrl)).rejects.toThrow();
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC55 - Ký hợp đồng - hợp đồng đã ký', () => {
    it('should throw ConflictException when contract is already signed by user', async () => {
      const userId = 10;
      const bookingId = 502;
      const signatureUrl = 'uploads/signature.png';

      const booking = {
        id: bookingId,
        userId,
        status: 'pending',
        contract: { id: 1, signedByUser: 'data:image/png;base64,old_sig' },
        room: { type: {} },
        user: {},
        bookingServices: [],
        roomChangeHistories: [],
        payments: [],
      };

      jest.spyOn(fs, 'access').mockResolvedValue(undefined as any);
      jest.spyOn(sharpUtil, 'hasSignature').mockResolvedValue(true);
      jest.spyOn(fs, 'unlink').mockResolvedValue(undefined as any);

      mockQueryRunner.manager.findOne.mockResolvedValue(booking);

      await expect(service.signContract(userId, bookingId, signatureUrl)).rejects.toThrow(ConflictException);
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });

  describe('TC56 - Ký hợp đồng - user không match', () => {
    it('should throw BadRequestException when user does not own the booking', async () => {
      const userId = 10;
      const otherUserId = 20;
      const bookingId = 503;
      const signatureUrl = 'uploads/signature.png';

      jest.spyOn(fs, 'access').mockResolvedValue(undefined as any);
      jest.spyOn(sharpUtil, 'hasSignature').mockResolvedValue(true);
      jest.spyOn(fs, 'unlink').mockResolvedValue(undefined as any);

      mockQueryRunner.manager.findOne.mockResolvedValue(null); // Booking không match user

      await expect(service.signContract(userId, bookingId, signatureUrl)).rejects.toThrow(BadRequestException);
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });
});