# 🚀 Secure WordPress Deployment on AWS

## 📌 Overview
Dự án triển khai WordPress trên AWS theo kiến trúc **Public–Private Subnet** để tăng tính bảo mật:
- **Public Subnet**: EC2-1 (Nginx reverse proxy).
- **Private Subnet**: EC2-2 (Apache + WordPress + MySQL).
- Database và ứng dụng WordPress không có public IP → an toàn hơn.

---

## 1️⃣ Chuẩn bị hạ tầng

1. **Tạo VPC với 2 subnet**: Public + Private.  
2. **Tạo Internet Gateway** và gắn với VPC.  
3. **Tạo NAT Gateway** trong Public subnet.  
4. **EC2-1 (Public subnet)**:  
   - OS: Ubuntu/Debian  
   - Elastic IP  
   - Security Group: allow HTTP (80), HTTPS (443), SSH (22)  
5. **EC2-2 (Private subnet)**:  
   - Security Group: chỉ allow port **3306 (MySQL)** và **9000 (PHP-FPM)** từ EC2-1  
   - Không cần Public IP  
6. **Tạo Route Table** và gắn cho từng subnet.  

---

### 🔑 SSH vào server

**EC2-1 (Public)**:
```bash
eval "$(ssh-agent -s)"
ssh-add /path/to/your-key.pem
ssh -A -i /path/to/abc.pem ubuntu@<Public-EC2-Elastic-IP>
```

**EC2-2 (Private)**:
```bash
ssh ubuntu@<Private-EC2-Private-IP>
```

---

## 2️⃣ Cài đặt MySQL (Private EC2 hoặc RDS)

```bash
sudo apt update
sudo apt install mysql-server -y
sudo mysql_secure_installation
sudo mysql -u root -p
```

**Tạo database và user (file `create-db.sql`):**
```sql
CREATE DATABASE wordpress;
CREATE USER 'wpuser'@'%' IDENTIFIED BY '<YOUR_DB_PASSWORD>';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
```

Cấu hình MySQL cho phép kết nối từ EC2-1:
```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```
Tìm dòng:
```
bind-address = 127.0.0.1
```
Sửa thành:
```
bind-address = 0.0.0.0
```

Khởi động lại:
```bash
sudo systemctl restart mysql
```

---

## 3️⃣ Cài đặt WordPress (EC2-2 Private)

```bash
sudo apt update
sudo apt install php php-mysql php-fpm unzip curl apache2 -y

cd /var/www
sudo curl -O https://wordpress.org/latest.tar.gz
sudo tar -xvzf latest.tar.gz
sudo mv wordpress /var/www/html
sudo chown -R www-data:www-data /var/www/html
```

Chỉnh `wp-config.php` để kết nối DB:
```php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wpuser');
define('DB_PASSWORD', '<YOUR_DB_PASSWORD>');
define('DB_HOST', '<Private-EC2-Private-IP>');
```

Cập nhật Virtual Host Apache:
```bash
sudo nano /etc/apache2/sites-available/000-default.conf
```
Sửa:
```
DocumentRoot /var/www/html
<Directory /var/www/html>
    AllowOverride All
</Directory>
DirectoryIndex index.php index.html
```

Kích hoạt **mod_rewrite**:
```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

---

## 4️⃣ Cài đặt Nginx reverse proxy (EC2-1 Public)

```bash
sudo apt update
sudo apt install nginx -y
```

Tạo file cấu hình `/etc/nginx/sites-available/wordpress`:
```nginx
server {
    listen 80;

    server_name _;

    location / {
        proxy_pass http://<Private-EC2-Private-IP>;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Kích hoạt site:
```bash
sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

Xoá site default nếu cần:
```bash
sudo rm /etc/nginx/sites-enabled/default
```

---

## 5️⃣ Kiểm tra

Trên EC2-1 (Public):
```bash
curl http://<EC2-Public-IP>
```

Mở trình duyệt → nhập Public IP (hoặc domain) → giao diện cài đặt WordPress.  

---

## ✅ Kết quả

- WordPress chạy thành công qua **Public EC2 (Nginx)**.  
- EC2 Private chứa WordPress + DB không lộ public IP.  
- Hệ thống có thể mở rộng:  
  - SSL (Let’s Encrypt).  
  - Load Balancer thay thế Nginx.  
  - RDS thay thế MySQL local.  

---
