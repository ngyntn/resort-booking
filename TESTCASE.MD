# 📑 Tài liệu Đặc tả Kiểm thử (Test Specification) - Resort Management System

Tài liệu này mô tả chi tiết các kịch bản kiểm thử (Test Cases) cho hệ thống quản lý Resort, áp dụng kỹ thuật **Bảng quyết định (Decision Table)** để đảm bảo độ bao phủ logic nghiệp vụ cao nhất.

---

## 🏗️ Cấu trúc Kỹ thuật (Technical Stack)

- **Backend:** NestJS, TypeORM, Jest, Supertest  
- **Frontend:** ReactJS, Playwright  
- **Quy tắc:**  
  - Sử dụng **Mocking** cho Unit Test  
  - Sử dụng **Test Database** cho E2E Test  

---

# 🏨 A. Usecase 1: Quản lý phòng (Room Management)

**Mô tả:**  
Admin thực hiện CRUD phòng. Kiểm tra ràng buộc về mã phòng, khoảng giá theo loại phòng và logic bảo trì.

## 1. Kiểm thử API Backend (Integration/E2E)

| ID   | Test Case                | Đầu vào (Payload/Action)                                  | Kết quả mong đợi (Expected)                          | Loại |
|------|-------------------------|-----------------------------------------------------------|-----------------------------------------------------|------|
| TC01 | Tạo phòng thành công     | roomNumber mới, price hợp lệ, role ADMIN                  | 201 Created, trả về thông tin phòng                  | POS  |
| TC02 | Trùng số phòng           | roomNumber đã tồn tại trong DB                            | 409 Conflict, "Room number already exists"           | NEG  |
| TC03 | Giá sai quy định         | price < minPrice hoặc > maxPrice                          | 400/409 Conflict, "Outside allowed range"            | NEG  |
| TC04 | Sai quyền hạn            | Token của role CUSTOMER                                   | 403 Forbidden                                       | NEG  |
| TC05 | Update bảo trì hợp lệ    | status: 'maintenance', startDate tương lai                | 200 OK, DB cập nhật thành công                       | POS  |
| TC06 | Thiếu ngày bảo trì       | status: 'maintenance', startDate: null                    | 400 Bad Request, "Date is required"                  | NEG  |
| TC07 | Ngày bảo trì quá khứ     | maintenanceStartDate < today                              | 400 Bad Request, "Cannot be in the past"             | NEG  |
| TC08 | Xóa phòng đang sử dụng   | DELETE phòng đang có Booking                              | 409 Conflict, "Data is being used"                   | NEG  |

## 2. Kiểm thử Frontend UI (Playwright)

- **UI_TC01 (POS):**  
  Đăng nhập Admin → Thêm phòng → Điền đúng thông tin → Submit → Hiển thị thông báo thành công và phòng mới xuất hiện trên Table.

- **UI_TC02 (NEG):**  
  Để trống "Số phòng/Giá" → Submit → UI hiển thị lỗi validation ngay tại field, không gọi API.

- **UI_TC03 (NEG):**  
  Chỉnh sửa phòng → Chọn "Bảo trì" → Chọn ngày quá khứ → Hệ thống báo lỗi ngay trên DatePicker hoặc lúc lưu.

---

# 📅 B. Usecase 2: Đặt phòng Resort (Booking Request)

**Mô tả:**  
Khách hàng đặt phòng. Kiểm tra lịch trống, sức chứa và tính toán giá tiền.

## 1. Kiểm thử API Backend

| ID   | Test Case              | Đầu vào (Payload/Action)                             | Kết quả mong đợi (Expected)                    | Loại |
|------|-----------------------|------------------------------------------------------|-----------------------------------------------|------|
| TC09 | Đặt phòng hợp lệ       | startDate/endDate tương lai, cap <= max              | 201 Created, status: pending                  | POS  |
| TC10 | Ngày ở quá khứ         | startDate: yesterday                                 | 400 Bad Request                               | NEG  |
| TC11 | Ngày trả < Ngày nhận   | startDate: 20/10, endDate: 18/10                     | 400 Bad Request                               | NEG  |
| TC12 | Quá sức chứa           | capacity: 5, room.maxPeople: 4                       | 400 Bad Request, "No more than X people"       | NEG  |
| TC13 | Trùng lịch đặt         | startDate/endDate giao với Booking cũ                | 409 Conflict, "Already been booked"            | NEG  |
| TC14 | Phòng đang bảo trì     | Đặt phòng có status: 'maintenance'                  | 409 Conflict, "Not available"                  | NEG  |

## 2. Kiểm thử Frontend UI

- **UI_TC04 (POS):**  
  Khách chọn ngày hợp lệ → Chọn dịch vụ → Total Price tự động tính đúng → Bấm đặt → Thông báo thành công.

- **UI_TC05 (NEG):**  
  Chọn số người vượt giới hạn → Nút "Submit" bị disable hoặc hiển thị cảnh báo.

- **UI_TC06 (NEG):**  
  Datepicker → Các ngày đã đặt/bảo trì bị disabled (không cho chọn).

---

# 🛡️ C. Usecase 3: Duyệt yêu cầu đặt phòng (Admin Approval)

**Mô tả:**  
Admin xử lý các yêu cầu đang chờ (Pending).

## 1. Kiểm thử API Backend

| ID   | Test Case                  | Đầu vào (Payload/Action)                     | Kết quả mong đợi (Expected)                | Loại |
|------|---------------------------|----------------------------------------------|-------------------------------------------|------|
| TC15 | Từ chối hợp lệ             | bookingId pending, có reason                 | 200 OK, status → rejected                 | POS  |
| TC16 | Từ chối thiếu lý do        | reason: "" hoặc null                         | 400 Bad Request                           | NEG  |
| TC17 | Từ chối sai trạng thái     | Booking đã confirmed                         | 403 Forbidden / 400 Bad Request           | NEG  |
| TC18 | Chấp nhận & tạo hợp đồng   | createContract cho Booking pending           | 200 OK, sinh file PDF/HTML hợp đồng       | POS  |

## 2. Kiểm thử Frontend UI

- **UI_TC07 (POS):**  
  Admin bấm "Từ chối" → Popup → Nhập lý do → Submit → Trạng thái chuyển đỏ (Rejected).

- **UI_TC08 (NEG):**  
  Bấm "Từ chối" → Để trống lý do → Xác nhận → Hiện lỗi "Lý do không được bỏ trống".

- **UI_TC09 (POS):**  
  Bấm "Chấp nhận" → Loading → Hiển thị nút "Tải hợp đồng" sau khi hoàn tất.

---

# 🤖 Prompt mẫu cho AI (GitHub Copilot / ChatGPT)

**Context:**  
Tôi đang phát triển hệ thống bằng **NestJS (Backend)** và **React (Frontend)**.

**Task:**  
Viết mã nguồn kiểm thử tự động cho Usecase `[Tên Usecase]` dựa trên các Test Case ở trên.

**Yêu cầu:**
1. **Backend:**  
   - Sử dụng Jest + Supertest  
   - Mock Repository bằng `jest.fn()`

2. **Frontend:**  
   - Sử dụng Playwright để giả lập hành vi người dùng  

3. **Tuân thủ đúng mã lỗi:**  
   - `400`, `403`, `409`