# WordPress Deployment on AWS (Public--Private Subnet Architecture)

## 1. Infrastructure Preparation

1.  Create a VPC with 2 subnets (public + private).
2.  Create an Internet Gateway and attach it to the VPC.
3.  Create a NAT Gateway in the public subnet.
4.  Launch **EC2-1** in the public subnet:
    -   OS: Ubuntu/Debian
    -   Attach Elastic IP
    -   Security Group: allow HTTP (80), HTTPS (443), SSH (22)
5.  Launch **EC2-2** in the private subnet:
    -   Security Group: allow only port 3306 (MySQL) and 9000 (PHP-FPM)
        from EC2-1
    -   No public IP needed
6.  Create 2 route tables and associate them with the respective
    subnets.

### SSH Access

-   **EC2-1 (Public)**:

    ``` bash
    eval "$(ssh-agent -s)"
    ssh-add /path/to/your-key.pem
    ssh -A -i /path/to/abc.pem ubuntu@<Public-EC2-Elastic-IP>
    ```

-   **EC2-2 (Private via Public Bastion)**:

    ``` bash
    ssh ubuntu@<Private-EC2-IP>
    ```

------------------------------------------------------------------------

## 2. Install MySQL (on EC2-2 or RDS)

``` bash
sudo apt update
sudo apt install mysql-server -y
sudo mysql_secure_installation
sudo mysql -u root -p
```

Create database and user for WordPress in a script file `create-db.sql`.

------------------------------------------------------------------------

## 3. Install WordPress (on EC2-2 private)

``` bash
sudo apt update
sudo apt install php php-mysql php-fpm unzip curl -y
cd /var/www
sudo curl -O https://wordpress.org/latest.tar.gz
sudo tar -xvzf latest.tar.gz
sudo mv wordpress /var/www/html
sudo chown -R www-data:www-data /var/www/html
```

### Configure WordPress

-   Edit `wp-config.php` to connect with MySQL.\

-   Configure MySQL to accept connections only from EC2-1 security
    group:

    ``` bash
    sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
    ```

    Change:

        bind-address = 127.0.0.1

    To:

        bind-address = 0.0.0.0

Restart MySQL:

``` bash
sudo systemctl restart mysql
```

------------------------------------------------------------------------

## 4. Install Nginx Reverse Proxy (on EC2-1 public)

``` bash
sudo apt update
sudo apt install nginx -y
```

Configure Nginx reverse proxy in `nginx.conf`.\
Enable the site:

``` bash
sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### Test

On Public EC2:

``` bash
curl http://<Public-EC2-IP>
```

If WordPress page is not shown, remove default site:

``` bash
sudo rm /etc/nginx/sites-enabled/default
```

------------------------------------------------------------------------

## 5. Configure Apache (on EC2-2 private)

Edit the default site:

``` bash
sudo nano /etc/apache2/sites-available/000-default.conf
```

Change document root:

    DocumentRoot /var/www/html

Add DirectoryIndex:

    <Directory /var/www/html>
        AllowOverride All
    </Directory>
    DirectoryIndex index.php index.html

Enable mod_rewrite (important for WordPress permalink):

``` bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

------------------------------------------------------------------------

## ✅ Final Result

-   WordPress site is accessible through Public EC2 via Nginx reverse
    proxy.
-   Apache + WordPress + MySQL are hidden in the private subnet for
    better security.
-   Future improvements:
    -   Replace MySQL with Amazon RDS.
    -   Use Load Balancer instead of a single Nginx proxy.
    -   Attach domain + SSL with Let's Encrypt for HTTPS.
