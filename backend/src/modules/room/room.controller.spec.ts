import { Test, TestingModule } from '@nestjs/testing';
import { RoomController } from './room.controller';
import { RoomService } from './room.service';
import { DataSource } from 'typeorm';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Room } from './entities/room.entity';
import { RoomType } from 'modules/room-type/entities/room-type.entity';
import { Media } from './entities/media.entity';
import { CreateRoomReqDto } from './dtos/create-room.dto';
import { UpdateRoomReqDto } from './dtos/update-room.dto';
import { QueryFailedError } from 'typeorm';
import { RoomStatus } from 'common/constants/room.constants';
import * as moment from 'moment';
import { ForbiddenException } from '@nestjs/common';
import { RolesGuard } from 'common/guards/roles.guard';
import * as fs from 'fs/promises';

describe('RoomController', () => {
  let controller: RoomController;
  let mockDataSource: any;
  let mockQueryRunner: any;
  let mockRoomRepository: any;
  let mockQueryBuilder: any;

  beforeEach(async () => {
    mockQueryBuilder = {
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      // Ép Jest phải chạy code bên trong TypeORM Brackets
      where: jest.fn().mockImplementation((condition: any) => {
        const cb = condition?.whereFactory || condition?.givenCb;
        if (typeof cb === 'function') cb(mockQueryBuilder);
        return mockQueryBuilder;
      }),
      andWhere: jest.fn().mockImplementation((condition: any) => {
        const cb = condition?.whereFactory || condition?.givenCb;
        if (typeof cb === 'function') cb(mockQueryBuilder);
        return mockQueryBuilder;
      }),
      orWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([[], 0]),
    };

    mockRoomRepository = {
      createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
    };

    mockQueryRunner = {
      connect: jest.fn().mockResolvedValue(undefined),
      startTransaction: jest.fn().mockResolvedValue(undefined),
      commitTransaction: jest.fn().mockResolvedValue(undefined),
      rollbackTransaction: jest.fn().mockResolvedValue(undefined),
      release: jest.fn().mockResolvedValue(undefined),
      manager: {
        findOne: jest.fn(),
        create: jest.fn(),
        save: jest.fn(),
        delete: jest.fn(),
        update: jest.fn(),
        find: jest.fn(),
      },
    };

    jest.spyOn(fs, 'access').mockResolvedValue(undefined as any);
    jest.spyOn(fs, 'unlink').mockResolvedValue(undefined as any);

    mockDataSource = {
      createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [RoomController],
      providers: [
        RoomService,
        { provide: DataSource, useValue: mockDataSource },
        { provide: getRepositoryToken(Room), useValue: mockRoomRepository },
      ],
    }).compile();

    controller = module.get<RoomController>(RoomController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('createRoom', () => {
    it('TC01 - Tạo phòng thành công đầy đủ thông tin', async () => {
      const payload: CreateRoomReqDto = {
        roomNumber: '101A',
        typeId: 1,
        maxPeople: 2,
        price: '150.00',
        description: 'Room for two guests',
        media: ['uploads/room-101A-1.jpg'],
      };

      const roomType = {
        id: 1,
        minPrice: '100.00',
        maxPrice: '200.00',
      };

      const createdRoom = {
        id: 123,
        roomNumber: payload.roomNumber,
        typeId: payload.typeId,
        maxPeople: payload.maxPeople,
        price: payload.price,
        description: payload.description,
        status: 'active',
      };

      const createdMedia = [
        {
          id: 1,
          roomId: createdRoom.id,
          path: payload.media[0],
        },
      ];

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity === Room) {
          return Promise.resolve(null);
        }
        if (entity === RoomType) {
          return Promise.resolve(roomType);
        }
        return Promise.resolve(null);
      });

      mockQueryRunner.manager.create.mockImplementation((entity: any, data: any) => data);
      mockQueryRunner.manager.save.mockResolvedValueOnce(createdRoom).mockResolvedValueOnce(createdMedia);

      const result = await controller.createRoom(payload);

      expect(mockDataSource.createQueryRunner).toHaveBeenCalled();
      expect(mockQueryRunner.connect).toHaveBeenCalled();
      expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.findOne).toHaveBeenCalledWith(Room, {
        where: {
          roomNumber: payload.roomNumber,
        },
      });
      expect(mockQueryRunner.manager.findOne).toHaveBeenCalledWith(RoomType, {
        where: {
          id: payload.typeId,
        },
      });
      expect(mockQueryRunner.manager.save).toHaveBeenCalledTimes(2);
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.rollbackTransaction).not.toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();

      expect(result).toEqual({
        statusCode: 200,
        isSuccess: true,
        data: {
          ...createdRoom,
          newMedia: createdMedia,
        },
        error: null,
      });
    });

    it('TC02 - Tạo phòng với roomNumber đã tồn tại', async () => {
      const payload: CreateRoomReqDto = {
        roomNumber: '101A',
        typeId: 1,
        maxPeople: 2,
        price: '150.00',
        description: 'Room for two guests',
        media: ['uploads/room-101A-1.jpg'],
      };

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity === Room) {
          return Promise.resolve({
            id: 1,
            roomNumber: payload.roomNumber,
          });
        }
        return Promise.resolve(null);
      });

      await expect(controller.createRoom(payload)).rejects.toMatchObject({
        response: {
          message: 'Room number already exists',
        },
      });

      expect(mockQueryRunner.connect).toHaveBeenCalled();
      expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).not.toHaveBeenCalled();
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();
    });

    it('TC03 - Tạo phòng với giá sai quy định', async () => {
      const payload: CreateRoomReqDto = {
        roomNumber: '101A',
        typeId: 1,
        maxPeople: 2,
        price: '250.00', // Price > maxPrice (200.00)
        description: 'Room for two guests',
        media: ['uploads/room-101A-1.jpg'],
      };

      const roomType = {
        id: 1,
        minPrice: '100.00',
        maxPrice: '200.00',
      };

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity === Room) {
          return Promise.resolve(null);
        }
        if (entity === RoomType) {
          return Promise.resolve(roomType);
        }
        return Promise.resolve(null);
      });

      await expect(controller.createRoom(payload)).rejects.toMatchObject({
        response: {
          message: 'The room price is outside the allowed price range for this room type',
        },
      });

      expect(mockQueryRunner.connect).toHaveBeenCalled();
      expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).not.toHaveBeenCalled();
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();
    });

    it('TC22 - Tạo phòng với RoomType không tồn tại', async () => {
      const payload: CreateRoomReqDto = {
        roomNumber: '999A',
        typeId: 9999,
        maxPeople: 2,
        price: '150.00',
        description: 'Room for two guests',
        media: ['uploads/room-999A.jpg'],
      };

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity === Room) {
          return Promise.resolve(null);
        }
        if (entity === RoomType) {
          return Promise.resolve(null);
        }
        return Promise.resolve(null);
      });

      await expect(controller.createRoom(payload)).rejects.toMatchObject({
        response: {
          message: 'Room type not found',
        },
      });

      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });

    it('TC23 - Lỗi bất ngờ khi lưu DB', async () => {
      const payload: CreateRoomReqDto = {
        roomNumber: '101A',
        typeId: 1,
        maxPeople: 2,
        price: '150.00',
        description: 'Room for two guests',
        media: ['uploads/room-101A-1.jpg'],
      };

      const roomType = {
        id: 1,
        minPrice: '100.00',
        maxPrice: '200.00',
      };

      mockQueryRunner.manager.findOne.mockImplementation((entity: any, options: any) => {
        if (entity === Room) {
          return Promise.resolve(null);
        }
        if (entity === RoomType) {
          return Promise.resolve(roomType);
        }
        return Promise.resolve(null);
      });

      mockQueryRunner.manager.create.mockImplementation((entity: any, data: any) => data);
      mockQueryRunner.manager.save.mockRejectedValue(new Error('Database connection error'));

      await expect(controller.createRoom(payload)).rejects.toThrow('Database connection error');
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();
    });
  });

  describe('getRooms', () => {
    it('TC19 - Lấy danh sách phòng mặc định', async () => {
      const query = { page: 1, limit: 10 };
      const mockRooms = [
        {
          id: 1,
          roomNumber: '101A',
          maxPeople: 2,
          price: '150.00',
          status: 'active',
          media: [],
          type: { id: 1, name: 'Standard' },
        },
      ];

      mockQueryBuilder.getManyAndCount.mockResolvedValue([mockRooms, 1]);

      const result = await controller.getRooms(query as any);

      expect(mockRoomRepository.createQueryBuilder).toHaveBeenCalledWith('room');
      expect(mockQueryBuilder.orderBy).toHaveBeenCalledWith('room.id', 'DESC');
      expect(mockQueryBuilder.skip).toHaveBeenCalledWith(0);
      expect(mockQueryBuilder.take).toHaveBeenCalledWith(10);
      expect(mockQueryBuilder.getManyAndCount).toHaveBeenCalled();
      expect(result.statusCode).toBe(200);
      expect(result.isSuccess).toBe(true);
      expect(result.data[0]).toEqual(mockRooms);
      expect(result.data[1]).toBe(1);
      expect(result.error).toBeNull();
    });

    it('TC20 - Lấy danh sách phòng có từ khóa', async () => {
      const query = { page: 1, limit: 10, keyword: '101' };
      const mockRooms = [
        {
          id: 1,
          roomNumber: '101A',
          maxPeople: 2,
          price: '150.00',
        },
      ];

      mockQueryBuilder.getManyAndCount.mockResolvedValue([mockRooms, 1]);

      const result = await controller.getRooms(query as any);

      expect(mockQueryBuilder.where).toHaveBeenCalled();
      expect(mockQueryBuilder.getManyAndCount).toHaveBeenCalled();
      expect(result.data[0]).toEqual(mockRooms);
      expect(result.data[1]).toBe(1);
    });

    it('TC21 - Lấy danh sách phòng full bộ lọc', async () => {
      const query = {
        page: 1,
        limit: 10,
        typeId: 1,
        maxPeople: 2,
        status: ['active'],
        priceRange: { minPrice: '100.00', maxPrice: '200.00' },
        dateRange: { startDate: '2026-01-03', endDate: '2026-01-05' },
      };
      const mockRooms = [
        {
          id: 1,
          roomNumber: '101A',
          maxPeople: 2,
          price: '150.00',
          status: 'active',
        },
      ];

      mockQueryBuilder.getManyAndCount.mockResolvedValue([mockRooms, 1]);

      const result = await controller.getRooms(query as any);

      expect(mockQueryBuilder.andWhere).toHaveBeenCalled();
      expect(mockQueryBuilder.getManyAndCount).toHaveBeenCalled();
      expect(result.data[0]).toEqual(mockRooms);
      expect(result.data[1]).toBe(1);
    });

    it('TC30 - Lấy ds phòng với keyword chuỗi và nhiều status (Bao phủ nhánh else)', async () => {
      const query = {
        page: 1, limit: 10,
        keyword: 'VIP', // Từ khóa chữ để không vào nhánh !isNaN
        status: ['active', 'maintenance'], // Mảng 2 phần tử để vào nhánh else (i > 0)
      };
      mockQueryBuilder.getManyAndCount.mockResolvedValue([[], 0]);
      await controller.getRooms(query as any);
      expect(mockQueryBuilder.orWhere).toHaveBeenCalled(); // Phải gọi orWhere cho 'maintenance'
    });
  });

  describe('updateRoom', () => {
    it('TC05 - Cập nhật trạng thái bảo trì hợp lệ', async () => {
      const roomId = 1;
      const payload: Partial<UpdateRoomReqDto> = {
        status: RoomStatus.MAINTENANCE,
        maintenanceStartDate: moment().add(1, 'day').format('YYYY-MM-DD'), // Tomorrow
      };

      const existingRoom = {
        id: roomId,
        roomNumber: '101A',
        typeId: 1,
        maxPeople: 2,
        price: '150.00',
        status: 'active',
        type: {
          minPrice: '100.00',
          maxPrice: '200.00',
        },
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(existingRoom);
      mockQueryRunner.manager.update.mockResolvedValue(undefined);

      const result = await controller.updateRoom(roomId, payload as UpdateRoomReqDto);

      expect(mockQueryRunner.connect).toHaveBeenCalled();
      expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.findOne).toHaveBeenCalledWith(Room, {
        where: { id: roomId },
        relations: ['type'],
      });
      expect(mockQueryRunner.manager.update).toHaveBeenCalledWith(
        Room,
        { id: roomId },
        expect.objectContaining({
          status: RoomStatus.MAINTENANCE,
          maintenanceStartDate: payload.maintenanceStartDate,
          updatedAt: expect.any(Date),
        })
      );
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.rollbackTransaction).not.toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();

      expect(result).toEqual({
        statusCode: 200,
        isSuccess: true,
        data: null,
        error: null,
      });
    });

    it('TC06 - Cập nhật bảo trì thiếu ngày', async () => {
      const roomId = 1;
      const payload: Partial<UpdateRoomReqDto> = {
        status: RoomStatus.MAINTENANCE,
        maintenanceStartDate: null,
      };

      await expect(controller.updateRoom(roomId, payload as UpdateRoomReqDto)).rejects.toMatchObject({
        response: {
          message: 'Maintenance start date is required when status is set to maintenance',
          error: 'BadRequest',
        },
      });
    });

    it('TC07 - Cập nhật bảo trì ngày trong quá khứ', async () => {
      const roomId = 1;
      const payload: Partial<UpdateRoomReqDto> = {
        status: RoomStatus.MAINTENANCE,
        maintenanceStartDate: moment().subtract(1, 'day').format('YYYY-MM-DD'), // Yesterday
      };

      await expect(controller.updateRoom(roomId, payload as UpdateRoomReqDto)).rejects.toMatchObject({
        response: {
          message: 'Maintenance start date cannot be in the past',
          error: 'BadRequest',
        },
      });
    });

    it('TC24 - Update với body rỗng', async () => {
      const roomId = 1;
      const payload = {} as UpdateRoomReqDto;

      const result = await controller.updateRoom(roomId, payload);

      expect(mockQueryRunner.manager.findOne).not.toHaveBeenCalled();
      expect(mockQueryRunner.rollbackTransaction).not.toHaveBeenCalled();
      expect(result).toEqual({
        statusCode: 200,
        isSuccess: true,
        data: null,
        error: null,
      });
    });

    it('TC25 - Update phòng không tồn tại', async () => {
      const roomId = 9999;
      const payload: Partial<UpdateRoomReqDto> = {
        description: 'Updated description',
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(null);

      await expect(controller.updateRoom(roomId, payload as UpdateRoomReqDto)).rejects.toMatchObject({
        message: 'Room not found',
      });

      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });

    it('TC26 - Update giá ngoài khoảng quy định', async () => {
      const roomId = 1;
      const payload: Partial<UpdateRoomReqDto> = {
        price: '300.00',
      };

      const room = {
        id: roomId,
        roomNumber: '101A',
        type: {
          minPrice: '100.00',
          maxPrice: '200.00',
        },
      };

      mockQueryRunner.manager.findOne.mockResolvedValue(room);

      await expect(controller.updateRoom(roomId, payload as UpdateRoomReqDto)).rejects.toMatchObject({
        response: {
          message: 'The room price is outside the allowed price range for this room type',
        },
      });

      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });

    it('TC27 - Update phòng kèm Media (ảnh mới)', async () => {
      const roomId = 1;
      const payload: Partial<UpdateRoomReqDto> = {
        media: ['uploads/room-101A-new.jpg'],
      };

      const room = {
        id: roomId,
        roomNumber: '101A',
        type: {
          minPrice: '100.00',
          maxPrice: '200.00',
        },
      };

      const oldMedia = [
        { id: 1, roomId, path: 'uploads/room-101A-old.jpg' },
        { id: 2, roomId, path: 'uploads/room-101A-old-2.jpg' },
      ];

      mockQueryRunner.manager.findOne.mockResolvedValue(room);
      mockQueryRunner.manager.find.mockResolvedValue(oldMedia);
      mockQueryRunner.manager.delete.mockResolvedValue({ affected: 2 });
      mockQueryRunner.manager.create.mockImplementation((entity, data) => data);
      mockQueryRunner.manager.save.mockResolvedValue([{ id: 3, roomId, path: payload.media[0] }]);

      const result = await controller.updateRoom(roomId, payload as UpdateRoomReqDto);

      expect(fs.unlink).toHaveBeenCalledTimes(2);
      expect(mockQueryRunner.manager.delete).toHaveBeenCalledWith(Media, { roomId });
      expect(mockQueryRunner.manager.save).toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(result).toEqual({
        statusCode: 200,
        isSuccess: true,
        data: null,
        error: null,
      });
    });

    it('TC28 - Bỏ qua lỗi khi xóa ảnh vật lý', async () => {
      const roomId = 1;
      const payload: Partial<UpdateRoomReqDto> = {
        media: ['uploads/room-101A-new.jpg'],
      };

      const room = {
        id: roomId,
        roomNumber: '101A',
        type: {
          minPrice: '100.00',
          maxPrice: '200.00',
        },
      };

      const oldMedia = [
        { id: 1, roomId, path: 'uploads/room-101A-old.jpg' },
      ];

      (fs.access as jest.Mock).mockRejectedValueOnce(new Error('File not found'));
      mockQueryRunner.manager.findOne.mockResolvedValue(room);
      mockQueryRunner.manager.find.mockResolvedValue(oldMedia);
      mockQueryRunner.manager.delete.mockResolvedValue({ affected: 1 });
      mockQueryRunner.manager.create.mockImplementation((entity, data) => data);
      mockQueryRunner.manager.save.mockResolvedValue([{ id: 2, roomId, path: payload.media[0] }]);

      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();
      const result = await controller.updateRoom(roomId, payload as UpdateRoomReqDto);
      consoleSpy.mockRestore();

      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(result).toEqual({
        statusCode: 200,
        isSuccess: true,
        data: null,
        error: null,
      });
    });

    it('TC31 - Update phòng giữ nguyên 1 ảnh cũ (Bao phủ nhánh filter media)', async () => {
      const roomId = 1;
      const payload: Partial<UpdateRoomReqDto> = { media: ['uploads/old.jpg', 'uploads/new.jpg'] };
      const room = { id: roomId, roomNumber: '101A', type: { minPrice: '100', maxPrice: '200' } };
      const oldMedia = [{ id: 1, roomId, path: 'uploads/old.jpg' }]; // Ảnh cũ vẫn nằm trong payload

      mockQueryRunner.manager.findOne.mockResolvedValue(room);
      mockQueryRunner.manager.find.mockResolvedValue(oldMedia);
      mockQueryRunner.manager.delete.mockResolvedValue({ affected: 1 });
      mockQueryRunner.manager.create.mockImplementation((entity, data) => data);
      mockQueryRunner.manager.save.mockResolvedValue([]);

      await controller.updateRoom(roomId, payload as UpdateRoomReqDto);
      expect(fs.unlink).not.toHaveBeenCalled(); // Hàm xóa file không được gọi vì ảnh cũ được giữ lại
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
    });
  });

  describe('deleteRoom', () => {
    it('TC08 - Xóa phòng đang có người đặt', async () => {
      const roomId = 1;

      const conflictError = new QueryFailedError('DELETE FROM room WHERE id = ?', [], new Error());
      (conflictError as any).code = 'ER_ROW_IS_REFERENCED_2';
      (conflictError as any).errno = 1451;

      mockQueryRunner.manager.delete.mockResolvedValueOnce(undefined) // Media delete succeeds
        .mockRejectedValueOnce(conflictError); // Room delete fails

      await expect(controller.deleteRoom(roomId)).rejects.toMatchObject({
        response: {
          error: 'DeleteConflict',
          message: 'Cannot delete because the data is being used elsewhere',
        },
      });

      expect(mockQueryRunner.connect).toHaveBeenCalled();
      expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.delete).toHaveBeenCalledWith(Media, { roomId });
      expect(mockQueryRunner.manager.delete).toHaveBeenCalledWith(Room, { id: roomId });
      expect(mockQueryRunner.commitTransaction).not.toHaveBeenCalled();
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();
    });

    it('TC29 - Xóa phòng thành công', async () => {
      const roomId = 1;

      mockQueryRunner.manager.delete.mockResolvedValue({ affected: 1 });

      const result = await controller.deleteRoom(roomId);

      expect(mockQueryRunner.connect).toHaveBeenCalled();
      expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.delete).toHaveBeenCalledWith(Media, { roomId });
      expect(mockQueryRunner.manager.delete).toHaveBeenCalledWith(Room, { id: roomId });
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();
      expect(result).toEqual({
        statusCode: 200,
        isSuccess: true,
        data: { affected: 1 },
        error: null,
      });
    });

    it('TC32 - Xóa phòng gặp lỗi DB bất ngờ (Không phải lỗi khóa ngoại)', async () => {
      const roomId = 1;
      // Trả về một lỗi chung chung không phải QueryFailedError
      mockQueryRunner.manager.delete.mockRejectedValueOnce(new Error('Lỗi máy chủ mất kết nối'));

      await expect(controller.deleteRoom(roomId)).rejects.toThrow('Lỗi máy chủ mất kết nối');
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });
  });
});

describe('RoomController - Authorization', () => {
  let controller: RoomController;

  beforeEach(async () => {
    const mockRoomService = {
      createRoom: jest.fn().mockRejectedValue(new ForbiddenException('Forbidden resource')),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [RoomController],
      providers: [
        { provide: RoomService, useValue: mockRoomService },
      ],
    })
      .overrideGuard(RolesGuard)
      .useValue({
        canActivate: jest.fn(() => true), // Allow guard to pass, test service level
      })
      .compile();

    controller = module.get<RoomController>(RoomController);
  });

  describe('createRoom', () => {
    it('TC04 - User thường (không phải ADMIN) tạo phòng', async () => {
      const payload: CreateRoomReqDto = {
        roomNumber: '101A',
        typeId: 1,
        maxPeople: 2,
        price: '150.00',
        description: 'Room for two guests',
        media: ['uploads/room-101A-1.jpg'],
      };

      await expect(controller.createRoom(payload)).rejects.toThrow(ForbiddenException);
    });
  });
});