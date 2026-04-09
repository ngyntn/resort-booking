
## **Flow Booking Trong Project Yasuo Resort**

### **📊 Tổng Quan**

Hệ thống booking gồm **3 phần chính**: Backend (NestJS), Frontend (React), và các điểm tích hợp. Flow chính là: **Khách đặt phòng → Admin tạo hợp đồng → Khách ký hợp đồng → Thanh toán**.

---

### **1. 🔧 Backend (NestJS) - Module Booking**

**Cấu trúc files chính:**
- booking.controller.ts - 12+ endpoints xử lý booking
- booking.service.ts - Logic phức tạp: validate, tính giá, transaction
- booking.entity.ts - Schema bảng booking

**Entities liên quan:**
- `Booking` - Bản ghi đặt phòng chính
- `BookingService` - Services gắn kèm booking
- `Contract` - Hợp đồng với chữ ký
- `RoomChangeHistory` - Lịch sử thay đổi phòng

#### **Các thao tác chính:**

| Thao tác | Hành động | Điều kiện |
|---------|----------|----------|
| **bookingRoom()** | Tạo booking mới | Kiểm tra availability, tính tổng giá (phòng + services - combo - voucher) |
| **createContract()** | Admin tạo PDF hợp đồng | Từ template EJS, embedded signature |
| **signContract()** | Khách ký hợp đồng | Status đổi: pending → confirmed |
| **rejectRoomBooking()** | Admin từ chối | Chỉ từ pending, gửi email |
| **cancelRoomBooking()** | Khách hủy | Chỉ booking pending của chính họ |
| **bookingServices()** | Thêm services | Thêm vào booking đã confirmed |

---

### **2. 🎨 Frontend (React) - Booking Pages**

**Các trang chính:**

| Trang | File | Người dùng | Chức năng |
|------|------|-----------|----------|
| **Booking** | Booking/index.jsx | Khách hàng | Chọn ngày, tính giá, tạo booking |
| **Booking Request** | BookingRequestPage/index.jsx | Admin | Quản lý bookings, tạo hợp đồng, ký |
| **Booking History** | BookingHistory.jsx | Khách hàng | Xem lịch sử đặt phòng |

**State Management:**
- `useBookings` hook - React Query cho data fetching
- Redux - Lưu user info

---

### **3. 🔄 Complete Booking Workflows**

#### **Workflow 1: Khách đặt phòng**
```
1. Khách chọn phòng → Chọn ngày check-in/out
2. Frontend: GET /booking (check availability)
3. Khách confirm
4. Frontend: POST /booking
5. Backend: Validate tất cả (dates, capacity, services, voucher)
6. Backend: Tính giá = room.price × ngày + services - combo discount - voucher
7. Backend: Tạo booking (status = 'pending')
8. Frontend: Hiện thông báo thành công
```

#### **Workflow 2: Admin tạo & khách ký hợp đồng**
```
1. Admin xem danh sách pending bookings
2. Admin click "Create Contract"
3. Backend: PUT /booking/{id}/create-contract
   - Render EJS template với booking details
   - Embed admin signature
   - Convert sang PDF (Puppeteer)
   - Lưu file
4. Admin preview hợp đồng
5. Khách nhận thông báo → ký hợp đồng (upload signature)
6. PUT /booking/{id}/sign-contract
7. Backend: Cập nhật contract + status = 'confirmed'
```

#### **Workflow 3: Quản lý services**
```
1. Customer/Admin: POST /booking/service (thêm service)
2. Backend: Validate service dates nằm trong booking period
3. Service tạo với status = 'pending'
4. Admin: PUT /booking/service/{id}/confirm hoặc reject
5. Services xuất hiện trong PDF hợp đồng
```

---

### **4. 📡 API Endpoints**

**Booking operations:**
- `GET /booking` - Lấy danh sách bookings
- `POST /booking` - Tạo booking mới
- `PUT /booking/{id}/sign-contract` - Ký hợp đồng
- `PUT /booking/{id}/create-contract` - Tạo hợp đồng
- `PUT /booking/{id}/reject-room-booking` - Admin từ chối
- `PUT /booking/{id}/cancel-room-booking` - Khách hủy
- `POST /booking/service` - Thêm service
- `PUT /booking/service/{id}/confirm` - Admin duyệt service

---

### **5. 🔐 Authorization**

- **Customer roles:** Có thể book, ký hợp đồng, hủy booking, xem booking history
- **Admin roles:** Tạo/từ chối hợp đồng, quản lý services, thay đổi phòng
- **Guard:** `RolesGuard` kiểm tra endpoints

---

### **6. 💰 Tính toán giá**

```
Total Price = (Room.price × days) + (Services cost)
            - Combo discount (if any)
            - Voucher discount (fixed or %, capped at max)
```

---

### **7. 📋 Booking Status Lifecycle**

```
pending 
  ├→ [Admin] tạo hợp đồng
  │   └→ [Customer] ký hợp đồng → confirmed
  │       └→ [Payment] xử lý thanh toán
  ├→ [Admin] reject → rejected
  └→ [Customer] cancel → cancelled
```

Hệ thống này đảm bảo quy trình booking hoàn chỉnh với validation ở mỗi bước, tính toán giá khoa học, và kiểm soát quyền hạn chặt chẽ! 🎯



## **Flow Room Management Trong Project Yasuo Resort**

### **📊 Tổng Quan**

Hệ thống quản lý phòng gồm **2 module chính** (Room & RoomType) ở Backend, với **2 giao diện** trên Frontend (Admin quản lý + Customer xem/filter). Flow chính đảm bảo phòng được quản lý đầy đủ với kiểm tra availability khi booking.

---

### **1. 🔧 Backend - Module Room**

#### **Entities**

| Entity | Mô tả | Trường quan trọng |
|--------|-------|------------------|
| **Room** | Phòng cụ thể | `roomNumber`, `typeId`, `maxPeople`, `price`, `status` (active/maintenance), `maintenanceStartDate`, `description` |
| **RoomType** | Loại phòng | `name`, `minPrice`, `maxPrice`, `description` |
| **Media** | Hình ảnh phòng | `path`, `roomId`, `comboId` |

**Mối quan hệ:**
- `Room` → `RoomType` (Many-to-One)
- `Room` → `Media` (One-to-Many, hình ảnh)
- `Room` → `Booking` (One-to-Many)

#### **API Endpoints - Room**

| Endpoint | Phương thức | Quyền | Chức năng |
|----------|-----------|-------|----------|
| `/room` | GET | Public | Lấy danh sách phòng với filter |
| `/room` | POST | Admin | Tạo phòng mới |
| `/room/:roomId` | PUT | Admin | Cập nhật phòng |
| `/room/:roomId` | DELETE | Admin | Xóa phòng |

#### **Service Logic**

**`getRooms(query)` - Lọc phòng:**
```
Nhập: keyword, typeId, maxPeople, priceRange, status, dateRange, page, limit

Xử lý:
1. LEFT JOIN với Media & RoomType
2. Filter theo keyword, typeId, maxPeople, status, price
3. **Kiểm tra availability**: Loại trừ phòng có booking trùng lịch
   WHERE room NOT IN (
     SELECT room_id FROM booking 
     WHERE status != 'cancelled' 
     AND start_date < dateRange.end 
     AND end_date > dateRange.start
   )
4. Pagination (SKIP/TAKE)

Output: [rooms[], totalCount]
```

**`createRoom(body)` - Tạo phòng:**
```
Transaction:
1. Validate roomNumber là duy nhất
2. Kiểm tra RoomType tồn tại
3. ✅ Validate giá phòng phải nằm trong
   RoomType.minPrice ≤ room.price ≤ RoomType.maxPrice
4. Lưu Room entity
5. Lưu Media entities (hình ảnh)
```

**`updateRoom(roomId, body)` - Cập nhật phòng:**
```
Transaction:
1. Validate maintenance logic
   - Nếu status = 'maintenance', maintenanceStartDate phải ngày trong tương lai
2. Validate giá (nếu thay đổi)
3. Cập nhật Room fields
4. Xủ lý media:
   - Xóa file cũ từ disk
   - Lưu file mới
5. Cập nhật Media entities
```

#### **API Endpoints - RoomType**

| Endpoint | Phương thức | Quyền | Chức năng |
|----------|-----------|-------|----------|
| `/room-type` | GET | Public | Lấy danh sách loại phòng |
| `/room-type` | POST | Admin | Tạo loại phòng |
| `/room-type/:roomTypeId` | PUT | Admin | Cập nhật loại phòng |
| `/room-type/:roomTypeId` | DELETE | Admin | Xóa loại phòng |

**Service Logic:**
- `createRoomType()`: Validate `minPrice ≤ maxPrice`
- `updateRoomType()`: Validate price range
- `deleteRoomType()`: Throw `ConflictException` nếu vẫn có phòng này

---

### **2. 🎨 Frontend - Admin Room Management**

**File:** RoomManagementPage/index.jsx

#### **Giao diện:**

**Table hiển thị:**
- Cột: Id | Room Number | Max People | Room Type | Status | Maintenance Date | Price | Created/Updated

**Filters:**
- Status dropdown (Active / Maintenance)

**Modals:**

| Modal | Chức năng |
|-------|-----------|
| **Create Modal** | Form tạo phòng mới: Room Number, Room Type dropdown, Max People, Price, Description (TextEditor), Media upload (PictureWall) |
| **Edit Modal** | Cùng fields create + Maintenance Date picker |

**Trạng thái render:**
- 🟢 "active" → Green tag
- 🟠 "maintenance" → Orange tag

#### **Data Flow - Admin tạo phòng:**
```
Form điền thông tin
  ↓ (validateFields)
CreateRoomReqDto {roomNumber, typeId, maxPeople, price, description, media[]}
  ↓ (POST /room via API)
Backend service validate
  - roomNumber unique?
  - RoomType tồn tại?
  - Price trong range [minPrice, maxPrice]?
  ↓ (transaction commit)
API return success
  ↓
Toast: "Phòng tạo thành công"
Table refresh (useFetch refetch)
```

---

### **3. 🎨 Frontend - Customer Room Browsing**

**File:** Rooms/index.jsx

#### **Giao diện:**

**Grid layout:** 4 phòng/trang

**Filter Card (FilterCard.jsx):**
```
- Room Type dropdown (from API)
- Number of Guests (input)
- Check-in date picker (min = ngày mai)
- Check-out date picker
- Price range slider (0-5000 USD)
```

**Room Card:**
- Hình ảnh phòng (carousel)
- Room Type + Room Number
- Giá (USD format)
- View details button
- Add to favorites ❤️

#### **Room Detail Dialog (RoomDetailDialog.jsx):**

**Layout:** 2 cột
- **Trái:** Image carousel (prev/next buttons, multiple images)
- **Phải:** Details
  - Room Type + Room Number
  - 👥 Capacity (maxPeople)
  - 💰 Price
  - 📝 Description
  - 🏷️ Status tag
  - 🎁 Services/Amenities (từ Combo)
  - ⭐ Ratings & Reviews
  - 📅 Book button (navigate to booking page)

---

### **4. 📡 Frontend API Layer**

**room.js:**
```javascript
getRooms(query)              // GET /room?page&limit&filters
createRoom(body)             // POST /room
updateRoom({param, body})    // PUT /room/{roomId}
deleteRoom({roomId})         // DELETE /room/{roomId}
getRecommendRoom(query)      // GET /recommender/room
```

**room-type.js:**
```javascript
getRoomTypes(query)          // GET /room-type?page&limit
createRoomType(body)         // POST /room-type
updateRoomType({param, body})// PUT /room-type/{roomTypeId}
deleteRoomType({roomTypeId}) // DELETE /room-type/{roomTypeId}
```

---

### **5. 🔄 Complete Workflows**

#### **Workflow 1: Customer lọc & xem phòng**
```
1. Customer vào trang Rooms
2. Filter Card hiện lên
3. Customer chọn:
   - Room Type (vd: VIP)
   - Số khách (vd: 2)
   - Check-in: 2024-01-15 (tối thiểu = ngày mai)
   - Check-out: 2024-01-18
   - Price range (vd: $100-$500)
4. Frontend: GET /room?typeId=1&maxPeople=2&priceRange=100-500
             &dateRange={start:'2024-01-15',end:'2024-01-18'}
5. Backend QueryBuilder:
   - SELECT rooms WHERE type, capacity, price match
   - EXCLUDE rooms có booking trùng dates
6. Grid hiển thị phòng khả dụng (4/trang)
7. Pagination
```

#### **Workflow 2: Xem chi tiết phòng**
```
1. Customer click "View details" trên room card
2. RoomDetailDialog mở
3. Hiển thị:
   - Image carousel (multi-images)
   - Room details (type, capacity, price, status)
   - Description + services/amenities
   - Reviews/ratings từ table feedback
4. Customer có thể:
   - Xem ảnh khác (prev/next)
   - Add to favorites
   - Click "Book" → navigate to booking page
```

#### **Workflow 3: Kiểm tra availability (date range)**
```
Query parameters từ frontend:
{
  startDate: '2024-01-15',
  endDate: '2024-01-18'
}

Backend SQL logic:
SELECT r.* FROM room r
WHERE r.id NOT IN (
  SELECT DISTINCT b.room_id FROM booking b
  WHERE b.status NOT IN ('cancelled', 'rejected')
  AND b.start_date < '2024-01-18'
  AND b.end_date > '2024-01-15'
)

✅ Kết quả: Chỉ phòng không có booking trùng lịch
```

#### **Workflow 4: Admin đặt phòng bảo trì**
```
1. Admin mở Edit Modal cho phòng
2. Thay đổi:
   - Status → "maintenance"
   - MaintenanceStartDate → chọn ngày tương lai (vd: 2024-02-01)
3. Frontend validate: maintenanceStartDate > today
4. PUT /room/{roomId}
5. Backend validate:
   - Nếu status='maintenance', cần maintenanceStartDate ngày trong tương lai
   - Cập nhật room fields
6. Toast: "Phòng cập nhật thành công"
7. Phòng này sẽ bị loại khỏi danh sách khả dụng từ maintenance date
```

---

### **6. 💡 Key Business Logic**

**Price Validation:**
```
Room được tạo/update phải:
RoomType.minPrice ≤ Room.price ≤ RoomType.maxPrice
```

**Availability Checking:**
```
Phòng chỉ hiển thị nếu:
- Status = 'active'  (không bảo trì)
- KHÔNG có booking trùng date range
- KHÔNG có booking pending/confirmed tại date đó
```

**Maintenance Workflow:**
```
Admin set status = 'maintenance'
  ↓
maintenanceStartDate (tương lai) bắt buộc
  ↓
Phòng ẩn khỏi tìm kiếm từ maintenance date
```

**Media Handling:**
```
Upload many images → Lưu vào Media entity
Update room → Xóa old files, lưu new files
Display → LEFT JOIN media, hiển thị carousel
```

---

### **7. 📋 Transaction & Data Integrity**

✅ **All CRUD operations** use database transactions
✅ **Rollback on error** - Nếu có lỗi, mọi thay đổi bị hủy
✅ **Foreign key validation** - RoomType phải tồn tại
✅ **Unique roomNumber** - Không trùng
✅ **Price range validation** - Phải nằm trong RoomType limit
✅ **Cascade delete** - Xóa Room → xóa Media

---

### **8. 📁 Files Chính**

| Loại | File | Mục đích |
|------|------|---------|
| **Entity** | room.entity.ts | Mô hình Room |
| | room-type.entity.ts | Mô hình RoomType |
| **Service** | room.service.ts | Query phức tạp + availability |
| **Admin UI** | RoomManagementPage/index.jsx | CRUD phòng |
| **Customer UI** | Rooms/index.jsx | Duyệt & filter |
| **Room Details** | RoomDetailDialog.jsx | Chi tiết + carousel |
| **API** | room.js | HTTP calls |

---

Hệ thống room management này đảm bảo phòng được quản lý chặt chẽ, availability kiểm tra đầy đủ, và customer chỉ thấy phòng thật sự khả dụng! 🏨✨