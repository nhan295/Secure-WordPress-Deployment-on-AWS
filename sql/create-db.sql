DROP USER 'iamnhan'@'localhost';
CREATE USER 'iamnhan'@'localhost' IDENTIFIED BY '<YOUR_DB_PASSWORD>';
GRANT ALL PRIVILEGES ON wordpress.* TO 'iamnhan'@'localhost';
FLUSH PRIVILEGES;
