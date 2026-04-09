import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { BookingController } from './booking.controller';
import { BookingService } from './booking.service';
import { RolesGuard } from 'common/guards/roles.guard';

describe('BookingController - Validation', () => {
  let app: INestApplication;
  let mockBookingService: any;

  beforeAll(async () => {
    mockBookingService = {
      rejectRoomBooking: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [BookingController],
      providers: [{ provide: BookingService, useValue: mockBookingService }],
    })
      .overrideGuard(RolesGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .compile();

    app = module.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('TC16 - Admin từ chối không có lý do nên trả về 400 Bad Request', async () => {
    const response = await request(app.getHttpServer())
      .put('/booking/123/reject-room-booking')
      .send({ reason: '' })
      .expect(400);

    expect(response.body).toHaveProperty('statusCode', 400);
    expect(response.body).toHaveProperty('message');
    expect(response.body.message).toEqual(
      expect.arrayContaining([expect.stringContaining('reason')]),
    );
    expect(mockBookingService.rejectRoomBooking).not.toHaveBeenCalled();
  });
});