# تک پوش خاص - راهنمای استقرار تولید

## نصب کامل با یک دستور

برای پاکسازی کامل سرور و نصب مجدد، این دستور را اجرا کنید:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/moha100h/TakPoshKhas/main/cleanup-and-install.sh)
```

## بررسی استقرار پس از نصب

برای تأیید موفقیت نصب:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/moha100h/TakPoshKhas/main/verify-deployment.sh)
```

## مشخصات سیستم مورد نیاز

- **سیستم عامل**: Ubuntu 22.04 LTS
- **حافظه**: حداقل 2GB RAM
- **فضای ذخیره**: حداقل 10GB
- **دسترسی**: root access
- **پورت‌ها**: 80, 443, 22

## ویژگی‌های نصب

### تنظیمات خودکار
- ✅ پاکسازی کامل سیستم
- ✅ نصب Node.js 20 LTS
- ✅ تنظیم PostgreSQL
- ✅ پیکربندی Nginx با SSL
- ✅ تنظیم فایروال
- ✅ سرویس systemd
- ✅ مانیتورینگ خودکار

### امنیت
- 🔒 تنظیمات امنیتی Nginx
- 🔒 محدودیت نرخ درخواست
- 🔒 هدرهای امنیتی
- 🔒 فایروال UFW
- 🔒 دسترسی‌های محدود

### عملکرد
- ⚡ فشرده‌سازی Gzip
- ⚡ کش استاتیک
- ⚡ Connection pooling
- ⚡ بهینه‌سازی پایگاه داده

## دسترسی پس از نصب

### وب‌سایت
```
http://YOUR-SERVER-IP
```

### پنل مدیریت
- **نام کاربری**: admin
- **رمز عبور**: password

### مانیتورینگ
```bash
# وضعیت سرویس
systemctl status tek-push-khas

# مشاهده لاگ‌ها
journalctl -u tek-push-khas -f

# بررسی عملکرد
curl http://localhost/api/health
```

## عیب‌یابی

### بررسی سرویس‌ها
```bash
# بررسی Node.js
systemctl status tek-push-khas

# بررسی Nginx
systemctl status nginx

# بررسی PostgreSQL
systemctl status postgresql
```

### لاگ‌ها
```bash
# لاگ اپلیکیشن
journalctl -u tek-push-khas -n 50

# لاگ Nginx
tail -f /var/log/nginx/error.log

# لاگ PostgreSQL
tail -f /var/log/postgresql/postgresql-*.log
```

### راه‌اندازی مجدد
```bash
# راه‌اندازی مجدد اپلیکیشن
systemctl restart tek-push-khas

# راه‌اندازی مجدد Nginx
systemctl restart nginx

# بازنشانی کامل
bash <(curl -Ls https://raw.githubusercontent.com/moha100h/TakPoshKhas/main/cleanup-and-install.sh)
```

## بک‌آپ و نگهداری

### بک‌آپ پایگاه داده
```bash
pg_dump -U tekpushuser -h localhost tekpushdb > backup.sql
```

### بازگردانی پایگاه داده
```bash
psql -U tekpushuser -h localhost tekpushdb < backup.sql
```

### به‌روزرسانی اپلیکیشن
```bash
cd /opt/tek-push-khas
git pull origin main
systemctl restart tek-push-khas
```

## تنظیمات اضافی

### SSL/HTTPS (اختیاری)
```bash
# نصب Certbot
apt install certbot python3-certbot-nginx

# دریافت گواهی SSL
certbot --nginx -d yourdomain.com
```

### دامنه سفارشی
فایل `/etc/nginx/sites-available/tek-push-khas` را ویرایش کنید:
```nginx
server_name yourdomain.com www.yourdomain.com;
```

## پشتیبانی

در صورت بروز مشکل:
1. لاگ‌ها را بررسی کنید
2. سرویس‌ها را مجدداً راه‌اندازی کنید
3. در صورت لزوم نصب مجدد انجام دهید

---

© 1404 تک پوش خاص - راهنمای فنی