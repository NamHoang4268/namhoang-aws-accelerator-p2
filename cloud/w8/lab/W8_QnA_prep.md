# W8 — Chuẩn bị QnA (K8s on AWS — Terraform 1-Click)

> **Mục tiêu:** Hiểu từng quyết định kỹ thuật trong code — tại sao viết như vậy, không phải tóm tắt bài làm.
> Trainer thường hỏi: _"Tại sao lại dùng cái này?"_ chứ không hỏi _"Cái này làm gì?"_

---

## 💡 CÁCH TRẢ LỜI CHO TỐT

- Nói bằng **ngôn ngữ của mình**, đừng cố nhớ thuật ngữ
- Luôn kèm **lý do**: "Em chọn X vì Y, nếu dùng Z thì sẽ bị W..."
- Khi trả lời, **kể câu chuyện** theo flow: "Đầu tiên... rồi... cuối cùng..."
- Nếu không biết → **nói thật rồi giải thích nguyên lý:** "Phần đó em chưa đọc kỹ, nhưng theo logic thì..."

---

# PHẦN 1 — Tại sao tách nhiều file `.tf`?

---

### ❓ Terraform chỉ cần `main.tf` là đủ, tại sao lại tách thành `network.tf`, `alb.tf`, `bootstrap.tf`,...?

**Trả lời đơn giản:**

> Terraform đọc **tất cả** file `.tf` trong cùng thư mục, không phân biệt tên. Tách file là để **con người** dễ đọc, không phải để Terraform hoạt động khác đi.
>
> Hãy nghĩ như tủ hồ sơ: tất cả giấy tờ đều có hiệu lực như nhau, nhưng bỏ tất cả vào 1 tập thì rất khó tìm. Tách ra: `network.tf` = hồ sơ mạng, `alb.tf` = hồ sơ load balancer, `bootstrap.tf` = hồ sơ cài đặt tự động — mỗi file 1 trách nhiệm rõ ràng.

---

### ❓ `k8s.tf` gần như rỗng, chỉ có comment. Tại sao giữ lại một file trống như vậy?

**Trả lời đơn giản:**

> File đó giải thích tại sao **KHÔNG** dùng `hashicorp/kubernetes` provider — đây là một quyết định thiết kế quan trọng.
>
> Nếu xóa file này, người đọc code sau 3 tháng (hoặc người khác trong team) sẽ hỏi: _"Sao không dùng kubernetes provider cho gọn?"_ — và không có câu trả lời nào ở đó. File này là "ghi chú nội bộ" cho team, không phải cho Terraform.

---

### ❓ Vậy lý do kỹ thuật cụ thể tại sao KHÔNG dùng `hashicorp/kubernetes` provider là gì?

**Trả lời đơn giản:**

> Nó gây ra vấn đề "Con gà và Quả trứng" khiến ta không thể chạy 1 lệnh (`terraform apply`) là xong hết (1-click):
>
> - Để provider `kubernetes` lập kế hoạch (`plan`), nó bắt buộc phải biết **Public IP của EC2** và **Token kết nối K8s**.
> - Nhưng nghịch lý ở chỗ: EC2 chưa được tạo thì lấy đâu ra IP? K8s chưa chạy thì lấy đâu ra Token? Terraform sẽ báo lỗi ngay lập tức vì không kết nối được.
>
> **Giải pháp của bài lab:** Bỏ việc bắt Terraform nhúng tay trực tiếp vào K8s. Ta đẩy việc chạy pod cho EC2 tự làm (qua file `user_data.sh`), và Terraform chỉ đóng vai trò người kiểm tra cuối cùng (qua `null_resource`).

---

# PHẦN 2 — Providers: tại sao cần đến 5 cái?

---

### ❓ Provider trong Terraform là gì?

**Trả lời đơn giản:**

> Provider giống như **plugin** — mỗi provider dạy Terraform biết cách nói chuyện với một dịch vụ cụ thể.
>
> Ví dụ: `hashicorp/aws` dạy Terraform cách tạo EC2, S3, VPC trên AWS. `hashicorp/tls` dạy Terraform cách tạo SSH key. Không có provider, Terraform không biết `aws_instance` hay `tls_private_key` là gì.

---

### ❓ `provider "null" {}` không cấu hình gì cả, tại sao vẫn phải khai báo?

**Trả lời đơn giản:**

> Trong Terraform, mọi provider đều phải được khai báo tường minh trước khi dùng. `null` provider rỗng vì không cần cấu hình gì (không có API key, không có region) — nhưng vẫn phải có mặt để `terraform init` tải plugin về.
>
> Không khai báo → `terraform init` không tải → dùng `null_resource` sẽ lỗi ngay.

---

### ❓ `null_resource` là gì? Nghe tên lạ vậy?

**Trả lời đơn giản:**

> `null_resource` là một resource **không tạo ra bất cứ thứ gì trên AWS** (không có EC2, không có S3,...). Nó chỉ có một mục đích duy nhất: **chạy lệnh shell** — hoặc trên máy cục bộ (`local-exec`) hoặc SSH vào server từ xa (`remote-exec`).
>
> Nó giống như một "nhân viên trung gian" — không xây dựng gì, chỉ đi kiểm tra và báo cáo. Trong bài này, `null_resource` SSH vào EC2 và hỏi: _"K8s đã sẵn sàng chưa?"_ rồi mới cho Terraform kết thúc.

---

### ❓ `local-exec` và `remote-exec` provisioner khác nhau thế nào?

**Trả lời đơn giản:**

> - **`local-exec`**: chạy lệnh **ngay trên máy đang chạy Terraform** (máy local hoặc CI/CD server). Ví dụ: `chmod 600 k8s-host.pem`
> - **`remote-exec`**: SSH vào máy chủ ở xa, chạy lệnh **bên trong** máy chủ đó. Ví dụ: vào EC2 kiểm tra K8s cluster có chạy không
>
> Hình ảnh dễ nhớ: `local-exec` = gọi điện tự làm việc, `remote-exec` = gọi điện nhờ người khác làm việc thay.

---

### ❓ `hashicorp/tls` provider dùng để làm gì? Tại sao không tự tạo SSH key bằng tay rồi upload?

**Trả lời đơn giản:**

> `tls_private_key` sinh ra cặp khóa SSH (private + public) **ngay bên trong Terraform**. Lợi ích lớn nhất: key này **gắn liền với vòng đời hạ tầng**.
>
> Khi chạy `terraform destroy`, toàn bộ hạ tầng + key đều bị xóa sạch. Không bao giờ còn key "mồ côi" nằm lại trên AWS console mà không biết dùng để làm gì.
>
> Tạo key bằng tay thì phải tự nhớ: xóa trên AWS sau khi xong, giữ file `.pem` ở đâu, share cho team ra sao — rất dễ quên và rủi ro bảo mật.

---

### ❓ `hashicorp/local` provider và `local_sensitive_file` là gì?

**Trả lời đơn giản:**

> Provider này cho phép Terraform **ghi file xuống máy cục bộ**. `local_sensitive_file` cụ thể là để ghi nội dung nhạy cảm (private key) — Terraform sẽ che nội dung file này trong mọi output, không in ra terminal.
>
> Đây là lý do file `k8s-host.pem` tự động xuất hiện sau `terraform apply` mà không cần copy-paste thủ công.

---

### ❓ `hashicorp/time` provider và `time_sleep` dùng để làm gì?

**Trả lời đơn giản:**

> `time_sleep` bắt Terraform **đứng chờ** một khoảng thời gian trước khi làm bước tiếp theo.
>
> Lý do cần: EC2 được tạo xong (theo Terraform) nhưng bên trong hệ điều hành vẫn đang khởi động, dịch vụ SSH (`sshd`) chưa start. Nếu `null_resource` SSH vào ngay, sẽ nhận lỗi `Connection refused`.
>
> `time_sleep` 90 giây = thời gian đủ để EC2 boot xong và SSH sẵn sàng đón kết nối.

---

# PHẦN 3 — `main.tf`: từng đoạn code quan trọng

---

### ❓ `required_version = ">= 1.9.0"` có tác dụng gì?

**Trả lời đơn giản:**

> Terraform sẽ từ chối chạy nếu phiên bản CLI thấp hơn 1.9.0. Đây là "khóa cứng" để đảm bảo cả team dùng cùng một phiên bản — tránh lỗi do cú pháp mới không tương thích với bản cũ.

---

### ❓ `version = "~> 6.0"` trong `required_providers` nghĩa là gì?

**Trả lời đơn giản:**

> `~>` đọc là "pessimistic constraint" — nghĩa là: chấp nhận `6.0`, `6.1`, `6.9`,... nhưng **từ chối `7.0`**.
>
> Chỉ cho phép tăng version nhỏ (patch/minor), không cho tăng version lớn (major) vì major version thường có breaking change. Đây là cách pin dependency an toàn mà không cứng nhắc quá (không cần viết `= 6.0.0` chính xác).

---

### ❓ `default_tags` trong `provider "aws"` hoạt động thế nào? Tại sao dùng cách này?

**Trả lời đơn giản:**

> Mọi resource AWS được tạo bởi provider này đều **tự động được gán tag** mà không cần viết lại trong từng resource.
>
> Thay vì phải thêm `Owner`, `Environment`, `Team` vào 15 resource khác nhau (EC2, VPC, ALB,...) — chỉ cần viết 1 lần trong `default_tags`, tất cả đều có. Khi cần thay đổi email owner, sửa 1 chỗ thay vì 15 chỗ.
>
> Tag quan trọng để theo dõi chi phí: AWS Cost Explorer có thể lọc "tốn bao nhiêu tiền cho Project hello-xbrain" nhờ tag `Project`.

---

### ❓ Security Group của EC2 cho phép NodePort từ ALB, nhưng tại sao không mở thẳng cho internet (`0.0.0.0/0`) cho tiện?

**Trả lời đơn giản:**

> Đây là mô hình bảo mật **nhiều lớp**: ALB đứng giữa internet và EC2, đóng vai trò "vệ sĩ".
>
> Nếu mở `30080` thẳng ra internet: bất kỳ ai cũng có thể bypass ALB và tấn công trực tiếp vào EC2. Security Group của EC2 chỉ nhận traffic `30080` từ **ALB Security Group** — nghĩa là chỉ ALB mới được phép vào, không ai khác.
>
> ```hcl
> security_groups = [aws_security_group.alb.id]  # chỉ từ ALB, không phải 0.0.0.0/0
> ```

---

### ❓ Port 8443 trong EC2 Security Group mở cho `0.0.0.0/0` — đây không phải lỗ hổng bảo mật sao?

**Trả lời đơn giản:**

> Đây là port Kubernetes API server của Minikube. Cần mở vì Terraform (chạy trên máy local) phải kết nối vào để verify cluster.
>
> Trong production thực tế, nên giới hạn IP (chỉ cho phép IP của máy Terraform). Trong lab, mở tất cả là tradeoff chấp nhận được — bảo mật giảm một chút, đổi lại không cần biết trước IP của người dùng.

---

### ❓ `user_data = file(...)` và `remote-exec` provisioner — hai cách cài phần mềm này khác nhau thế nào?

**Trả lời đơn giản:**

> - **`user_data`**: EC2 tự chạy script ngay khi boot, **không cần SSH**, chạy với quyền root. Terraform không đợi script xong.
> - **`remote-exec`**: Terraform SSH vào, chạy lệnh, **đợi kết quả** rồi mới tiếp tục.
>
> `user_data` phù hợp hơn cho cài đặt phần mềm (Docker, Minikube, kubectl) vì: EC2 tự cài ngầm trong khi Terraform tạo ALB, Security Group song song — tiết kiệm thời gian. `remote-exec` dùng để verify sau khi cài xong.

---

### ❓ `root_block_device { volume_size = 20 }` — tại sao phải chỉ định disk? Để mặc định không được sao?

**Trả lời đơn giản:**

> Default của AMI Ubuntu chỉ có **8GB**. Minikube pull Docker images, chạy containers, lưu K8s state — dễ đầy disk trong quá trình bootstrap. Hết disk = toàn bộ hệ thống crash.
>
> `gp3` thay vì `gp2`: cùng giá nhưng `gp3` có baseline 3000 IOPS không phụ thuộc vào dung lượng — `gp2` chỉ 100 IOPS với 8GB, rất chậm khi cài phần mềm.

---

# PHẦN 4 — `network.tf`: mạng và subnet

---

### ❓ EC2 chỉ đặt trong 1 subnet, tại sao phải tạo đến 2 subnet?

**Trả lời đơn giản:**

> Không phải em chọn 2, mà **AWS ép phải có 2** — đây là điều kiện bắt buộc của ALB (Application Load Balancer).
>
> ALB cần trải rộng qua ít nhất 2 Availability Zone (AZ) để tự nó có thể chịu lỗi. Nếu chỉ có 1 subnet, `terraform apply` sẽ báo lỗi ngay từ bước tạo ALB.

---

### ❓ Vậy subnet thứ 2 tạo ra chỉ để "làm cảnh" thôi đúng không? Có bị tính phí lãng phí không?

**Trả lời đơn giản:**

> Đúng là trong lab này nó chỉ để "làm cảnh" thỏa mãn điều kiện của ALB, bên trong không có EC2 nào cả.
>
> Tuy nhiên, **nó hoàn toàn MIỄN PHÍ ($0)**. Trên AWS, các thành phần mạng logic như VPC, Subnet, Route Table không bị tính phí. Bạn chỉ trả tiền cho máy ảo (EC2) hoặc dịch vụ đặt _bên trong_ subnet đó. Vì subnet 2 trống rỗng nên ta không mất đồng nào.
>
> _Lưu ý thêm:_ Trong thực tế (production), người ta sẽ chạy kiến trúc Multi-AZ, tức là rải đều EC2 ra cả 2 subnet để chia tải. Bài lab chỉ chạy 1 EC2 (Single-AZ) để tiết kiệm chi phí sinh viên.

---

### ❓ Nếu subnet 2 trống rỗng, ALB có vô tình đẩy traffic (tải) vào đó rồi bị lỗi không?

**Trả lời đơn giản:**

> Không. ALB không đẩy traffic mù quáng vào "Subnet". ALB đẩy traffic vào **"Target Group"** (Nhóm đích).
>
> Trong code, ta chỉ đăng ký đúng 1 con EC2 (nằm ở subnet 1) vào Target Group. Do đó, khi nhận traffic, ALB nhìn vào Target Group và đẩy **100% traffic** thẳng vào con EC2 đó. Subnet 2 chỉ là chỗ để ALB đặt chân (tạo network interface) nhằm dự phòng sập data center, chứ không ảnh hưởng đến luồng chia tải.

---

### ❓ `map_public_ip_on_launch = true` trong subnet cần thiết không? Bỏ đi có sao không?

**Trả lời đơn giản:**

> **Bỏ đi thì hỏng toàn bộ flow**. Nếu không có dòng này, EC2 chỉ có Private IP (`10.0.x.x`) — không thể SSH từ ngoài internet vào, và `null_resource` remote-exec sẽ không kết nối được.
>
> Public IP là địa chỉ để thế giới bên ngoài tìm thấy EC2.

---

# PHẦN 5 — `alb.tf`: Load Balancer gồm 4 resource

---

### ❓ Tại sao bắt buộc dùng ALB trong khi lab chỉ có 1 EC2 (đâu có tác dụng chia tải)?

**Trả lời đơn giản:**

> - **Thứ nhất (Requirement):** Đây là yêu cầu bắt buộc của đề bài. Mục đích là chứng minh bạn biết cách dùng Terraform dệt (integrate) các service lại với nhau.
> - **Thứ hai (Kỹ thuật):** Dù không chia tải, ALB vẫn mang lại giá trị lớn:
>     1. **Che giấu server:** Người dùng chỉ thấy DNS của ALB, không bao giờ biết được IP thật của máy chủ EC2 (bảo mật).
>     2. **DNS cố định:** IP của EC2 có thể đổi nếu tắt bật lại, nhưng URL của ALB là cố định.
>     3. **Mở rộng dễ dàng:** Sau này muốn gắn chứng chỉ bảo mật HTTPS (SSL/TLS), ta gắn thẳng lên ALB chỉ bằng vài cú click, EC2 bên trong không cần sửa gì.

---

### ❓ ALB cần 4 resource riêng biệt? Tại sao phức tạp vậy?

**Trả lời đơn giản:**

> Mỗi resource có vai trò độc lập:
>
> | Resource                         | Vai trò                               | Ví dụ thực tế                           |
> | -------------------------------- | ------------------------------------- | --------------------------------------- |
> | `aws_lb`                         | ALB thật, nơi AWS gán DNS             | Tòa nhà                                 |
> | `aws_lb_target_group`            | Định nghĩa "nhóm đích" + health check | Danh sách phòng ban + quy tắc kiểm tra  |
> | `aws_lb_target_group_attachment` | Đăng ký EC2 vào target group          | Thêm tên nhân viên vào phòng ban        |
> | `aws_lb_listener`                | Lắng nghe port 80, forward đến group  | Lễ tân nhận khách và dẫn đến đúng phòng |
>
> Tách ra giúp linh hoạt: có thể đăng ký nhiều EC2 vào cùng target group, hoặc một ALB có nhiều listener (port 80, port 443) cùng lúc.

---

### ❓ Health check `healthy_threshold = 2`, `unhealthy_threshold = 3` — tại sao hai ngưỡng khác nhau?

**Trả lời đơn giản:**

> ALB định kỳ gọi `GET /` vào EC2:30080 để kiểm tra.
>
> - **Healthy**: cần 2 lần thành công liên tiếp mới chuyển sang "healthy"
> - **Unhealthy**: cần 3 lần thất bại liên tiếp mới chuyển sang "unhealthy"
>
> Ngưỡng unhealthy cao hơn (3 vs 2) vì: khi pod mới khởi động, nó có thể fail 1-2 lần trước khi sẵn sàng. Nếu ngưỡng chỉ là 2, ALB sẽ đánh dấu unhealthy quá sớm rồi lại healthy — gọi là "flip-flop". Ngưỡng 3 cho pod thời gian khởi động ổn định hơn.

---

# PHẦN 6 — `bootstrap.tf`: cơ chế verify tự động

---

### ❓ Vấn đề "Con gà và Quả trứng" khi dùng Kubernetes provider trong Terraform là gì?

**Trả lời đơn giản:**

> Để Terraform dùng `kubernetes` provider deploy app, nó cần biết **IP của EC2 và token K8s** ngay ở bước lập kế hoạch (plan).
>
> Nhưng EC2 chưa được tạo → chưa có IP → chưa có K8s → chưa có token. Terraform báo lỗi ngay từ đầu — vòng tròn không có điểm bắt đầu.
>
> **Giải pháp:** Đẩy toàn bộ logic K8s (Deployment, Service) vào `user_data.sh` — EC2 tự cài và deploy sau khi boot. Terraform không cần biết K8s token, chỉ cần SSH vào kiểm tra kết quả cuối.

---

### ❓ `triggers` trong `null_resource` làm gì?

**Trả lời đơn giản:**

> Terraform mặc định chỉ chạy lại resource khi bản thân resource bị thay đổi. Nhưng `null_resource` không quản lý gì cả — nên Terraform không biết khi nào cần chạy lại.
>
> `triggers` là cách nói với Terraform: _"Nếu những giá trị này thay đổi, hãy chạy lại tôi"_.
>
> - `instance_id` thay đổi → EC2 bị recreate → cần verify lại cluster mới
> - `user_data_sha` thay đổi → script bootstrap thay đổi → cần verify lại kết quả mới

---

### ❓ Tại sao `depends_on = [time_sleep.wait_for_ssh]` mà không phải `depends_on = [aws_instance.k8s_host]`?

**Trả lời đơn giản:**

> Nếu depends vào EC2 trực tiếp: EC2 "tạo xong" theo Terraform không có nghĩa là SSH daemon đã start — EC2 vẫn đang boot bên trong.
>
> `time_sleep` thêm 90 giây buffer sau khi EC2 "tạo xong". Sau 90 giây, SSH daemon chắc chắn đã chạy rồi mới kết nối. Không có buffer này, `null_resource` SSH vào và nhận `Connection refused`.

---

### ❓ `bootstrap.tf` có 3 `provisioner "remote-exec"` liên tiếp — gộp lại thành 1 không được sao?

**Trả lời đơn giản:**

> Được về mặt kỹ thuật, nhưng tách ra để **dễ debug hơn nhiều**.
>
> Nếu gộp vào 1 block: khi lỗi, Terraform chỉ báo "step 1 failed" không biết bị ở đâu. Tách thành 3 step rõ ràng:
>
> 1. Chờ bootstrap xong
> 2. Verify K8s nodes
> 3. Verify app pods
>
> → Khi lỗi biết ngay: "step 2 failed" = K8s chưa ready, "step 3 failed" = app chưa deploy.

---

### ❓ `/tmp/bootstrap_done` là gì? Giải thích cơ chế "Polling" (Hỏi liên tục) ở đây?

**Trả lời đơn giản:**

> Cơ chế Polling ở đây là việc Terraform **cứ 15 giây lại quét hệ thống một lần** để tìm file `/tmp/bootstrap_done`. Giống như gọi điện hỏi nhân viên "Xong chưa?", chưa xong thì 15 giây sau gọi lại.
>
> - **Nguyên lý:** `user_data.sh` chạy ngầm (background). Ở dòng cuối cùng của script này, ta đặt lệnh tạo ra file rỗng `/tmp/bootstrap_done`. Nó giống như hành động cắm cờ báo hiệu "TÔI CÀI XONG K8s RỒI!".
> - Khi Terraform (thông qua lệnh `until [ -f ... ]; do sleep 15; done`) thấy lá cờ này xuất hiện, nó biết quá trình cài đặt phần mềm đã hoàn tất và bắt đầu chuyển sang chạy `kubectl` để verify.
>
> **Lưu ý cực kỳ quan trọng:** Thấy file này KHÔNG CÓ NGHĨA là "EC2 đã khởi động xong" (việc đó xảy ra rất nhanh ở phút đầu tiên). Thấy file này có nghĩa là **"Kubernetes và Ứng dụng đã được tải & cài đặt thành công"** (quá trình này mất 3-5 phút).

---

# PHẦN 7 — `scripts/user_data.sh`

---

### ❓ Dòng đầu `exec > /var/log/user_data.log 2>&1` có tác dụng gì?

**Trả lời đơn giản:**

> Redirect toàn bộ output (kể cả lỗi) của script vào file log.
>
> `user_data.sh` chạy lúc EC2 boot, không có terminal để xem — nếu script lỗi, không có cách nào biết tại sao. File log này cho phép SSH vào và xem lại toàn bộ lịch sử bằng `tail -f /var/log/user_data.log`.
>
> `2>&1` = "stderr gộp vào cùng chỗ với stdout" — bắt cả lỗi lẫn thông tin bình thường.

---

### ❓ `--apiserver-ips=$(curl 169.254.169.254/...)` khi start Minikube — tại sao cần option lạ này?

**Trả lời đơn giản:**

> Mặc định, Minikube cấp TLS certificate cho K8s API server chỉ với `localhost` và IP nội bộ.
>
> Khi Terraform từ máy local SSH vào và gọi kubectl qua Public IP của EC2 (ví dụ `32.x.x.x`), cert sẽ bị từ chối vì **IP không nằm trong danh sách được phép** của cert.
>
> Option `--apiserver-ips` thêm Public IP của EC2 vào cert — Terraform kết nối qua IP đó mà không bị TLS error.

---

### ❓ Tại sao cần `socat` ở bước 6.5? Không có thì ALB không hoạt động được sao?

**Trả lời đơn giản:**

> Đúng, không có `socat` thì ALB báo 502 Bad Gateway.
>
> Khi Minikube chạy với `--driver=docker`, K8s node thực ra là **container** với IP riêng (ví dụ `192.168.49.2`). NodePort 30080 chỉ lắng nghe ở IP đó, không phải ở IP của EC2 host.
>
> ALB health check gõ cửa `EC2-IP:30080` — không có ai đón → 502. `socat` là "người đón cửa": nhận traffic ở `EC2-IP:30080` và chuyển vào `192.168.49.2:30080` cho Minikube.

---

### ❓ `socat` là gì? Có thể thay bằng thứ khác không?

**Trả lời đơn giản:**

> `socat` = **So**cket **Cat** — công cụ nối 2 luồng mạng bất kỳ với nhau. Đơn giản, nhẹ, cài 1 lệnh.
>
> Có thể thay bằng `nginx` reverse proxy hoặc `iptables` port forward — nhưng cả hai cần cấu hình phức tạp hơn. `socat` là lựa chọn nhanh nhất cho lab.

---

### ❓ Tại sao Deployment dùng `initContainer` để tạo HTML thay vì build custom Docker image?

**Trả lời đơn giản:**

> Build custom image cần: viết Dockerfile → build → push lên Docker Hub/ECR → pull khi deploy. Mỗi bước cần thêm cấu hình, account, auth token.
>
> `initContainer` dùng `busybox` (image cực nhỏ, có sẵn) để echo HTML vào shared volume trước khi nginx chạy. Không cần registry, không cần auth. Đánh đổi: HTML bị hardcode trong manifest, không tách biệt code và config — nhưng cho lab là hoàn toàn ổn.

---

### ❓ Service type `NodePort` với port cố định `30080` — tại sao không để Kubernetes tự chọn port?

**Trả lời đơn giản:**

> Nếu để K8s tự chọn, port sẽ random trong range 30000-32767 và **thay đổi mỗi lần** apply lại.
>
> ALB target group, EC2 Security Group, và `socat` đều cần biết port cụ thể trước. Nếu port thay đổi, 3 chỗ đó đều phải cập nhật theo. Cố định `30080` đảm bảo 4 thứ này luôn nhất quán với nhau: K8s Service → `socat` → EC2 SG → ALB target group.

---

# PHẦN 8 — `variables.tf` và `terraform.tfvars`

---

### ❓ Variable đã có `default` trong `variables.tf`, tại sao vẫn khai báo lại trong `terraform.tfvars`?

**Trả lời đơn giản:**

> `terraform.tfvars` là nơi ghi giá trị **thực tế đang dùng** — người đọc không cần mở `variables.tf` để biết lab đang chạy gì.
>
> Ngoài ra, `terraform.tfvars` là điểm override duy nhất. Muốn deploy ở region khác, instance type khác → chỉ sửa file này, không chạm vào code.

---

### ❓ `minikube_ready_wait = 90` — con số 90 giây này có ý nghĩa gì? Tại sao có bài lab khác để đến 300 giây?

**Trả lời đơn giản:**

> 90 giây là khoảng thời gian "đệm" để chờ **hệ điều hành (Ubuntu) boot xong và dịch vụ SSH (`sshd`) sẵn sàng mở cửa**. Lúc này hạ tầng (AWS) tạo xong rồi, nhưng phần mềm (HĐH) vẫn đang lóc cóc khởi động.
>
> Tại sao ta tự tin dùng 90s thay vì 300s như chỗ khác?
>
> - **Thông minh hơn nhờ Polling:** Những bài dùng 300s là họ đang "đoán mò" (ngồi chờ chết) để xem script `user_data` cài phần mềm xong chưa. Còn lab của ta dùng cơ chế Polling (tìm file cờ) thông minh hơn nhiều. Ta chỉ cần 90s để SSH vào được EC2, sau đó tự động poll đến khi nào xong thì thôi.
> - **Khác biệt hệ điều hành:** Windows Server mất rất nhiều thời gian (khoảng 300s) để boot và sysprep. Ubuntu Linux nhẹ hơn rất nhiều, 90s đã là dư dả gấp đôi.
> - **Trải nghiệm DevEx:** Đợi 90s thay vì ngồi chờ 5 phút mỗi lần `terraform apply` giúp quá trình feedback loop nhanh hơn hẳn.

---

# PHẦN 9 — `outputs.tf`

---

### ❓ `dns_name` của ALB từ đâu ra? Ta có đặt tên nó không?

**Trả lời đơn giản:**

> AWS **tự sinh** khi tạo ALB — theo format: `[tên-ALB]-[số-ngẫu-nhiên].[region].elb.amazonaws.com`. Ta không đặt tên cái URL đó, chỉ đặt tên ALB (ví dụ `hello-xbrain-alb`).
>
> Sau khi Terraform tạo xong ALB, AWS trả về JSON chứa `dns_name`. Terraform lưu vào state, `outputs.tf` lấy ra bằng `aws_lb.main.dns_name` và in lên màn hình.

---

### ❓ `app_nodeport_url` output để làm gì khi đã có `alb_url`?

**Trả lời đơn giản:**

> Dùng để **debug phân tầng**.
>
> Khi ALB URL trả về lỗi, cần biết lỗi ở tầng nào:
>
> - NodePort URL OK, ALB URL lỗi → vấn đề ở ALB config (listener, target group)
> - Cả hai đều lỗi → vấn đề ở K8s/app hoặc `socat`
>
> Không có NodePort URL, rất khó xác định nguyên nhân khi debug.

---

# 📋 BẢNG TRA CỨU NHANH

| Thứ                   | Giá trị     | Tại sao                                   |
| --------------------- | ----------- | ----------------------------------------- |
| Instance type         | `t3.medium` | Minikube cần ≥ 2 vCPU, 2GB RAM            |
| Disk                  | `20GB gp3`  | Default 8GB không đủ cho Docker images    |
| NodePort              | `30080`     | Cố định để ALB SG socat nhất quán         |
| `minikube_ready_wait` | `90s`       | Buffer cho EC2 boot + sshd start          |
| Số subnet             | `2`         | Hard requirement của ALB                  |
| `socat`               | Bắt buộc    | Minikube docker driver cô lập network     |
| `/tmp/bootstrap_done` | Signal file | Giao tiếp giữa user_data và null_resource |
