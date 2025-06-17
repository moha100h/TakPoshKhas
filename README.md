# تک پوش خاص - نصب خودکار

سیستم مدیریت برند تی‌شرت فارسی با نصب یک خطی

## نصب فوری

```bash
bash <(curl -Ls https://raw.githubusercontent.com/moha100h/tek-push-khas-install/main/complete-install.sh)
```

## ویژگی‌ها

- ✅ نصب کاملاً خودکار (5-10 دقیقه)
- ✅ پشتیبانی از Ubuntu/Debian/CentOS
- ✅ تشخیص خودکار سیستم‌عامل
- ✅ نصب خودکار Node.js و PostgreSQL
- ✅ پیکربندی خودکار Nginx و SSL
- ✅ فایروال و امنیت خودکار
- ✅ پنل مدیریت جامع
- ✅ سیستم آپلود تصاویر
- ✅ طراحی ریسپانسیو

## استفاده

### نصب اولیه
```bash
# ورود به سرور
ssh root@your-server-ip

# نصب خودکار
bash <(curl -Ls https://raw.githubusercontent.com/moha100h/tek-push-khas-install/main/complete-install.sh)
```

### سوالات نصب
اسکریپت تنها سه سوال می‌پرسد:
1. دامنه سایت (اختیاری برای SSL)
2. نام کاربری ادمین (پیش‌فرض: admin)
3. رمز عبور ادمین (پیش‌فرض: admin123)

### پس از نصب
- سایت روی آدرس IP یا دامنه شما فعال می‌شود
- پنل مدیریت با نام کاربری و رمز تنظیم شده قابل دسترسی است
- تمام سرویس‌ها خودکار راه‌اندازی می‌شوند

## مدیریت

### دستورات کلیدی
```bash
# وضعیت سیستم
sudo systemctl status tek-push-khas

# راه‌اندازی مجدد
sudo systemctl restart tek-push-khas

# مشاهده لاگ
sudo journalctl -u tek-push-khas -f

# پشتیبان‌گیری
sudo /usr/local/bin/backup-tek-push-khas
```

### به‌روزرسانی
```bash
bash <(curl -Ls https://raw.githubusercontent.com/moha100h/tek-push-khas-install/main/update.sh)
```

## پیش‌نیازها

- سرور با Ubuntu 20.04+ یا Debian 11+ یا CentOS 8+
- حداقل 2GB RAM (توصیه شده 4GB)
- حداقل 20GB فضای ذخیره‌سازی
- دسترسی root یا sudo
- پورت‌های 80 و 443 باز

## ساختار فایل‌ها

```
/opt/tek-push-khas/           # مسیر اصلی اپلیکیشن
├── client/                   # فایل‌های فرانت‌اند
├── server/                   # فایل‌های بک‌اند
├── uploads/                  # تصاویر آپلود شده
├── .env                      # تنظیمات محیط
└── package.json              # وابستگی‌ها

/var/log/tek-push-khas/       # لاگ‌های سیستم
/opt/backups/                 # فایل‌های پشتیبان
```

## مشکلات رایج

### سایت دسترسی ندارد
```bash
# بررسی وضعیت سرویس‌ها
sudo systemctl status tek-push-khas nginx

# بررسی لاگ‌ها
sudo journalctl -u tek-push-khas --since "1 hour ago"
```

### خطای 502 Bad Gateway
```bash
# بررسی پورت اپلیکیشن
sudo netstat -tulpn | grep :3000

# راه‌اندازی مجدد
sudo systemctl restart tek-push-khas
```

### مشکل آپلود تصاویر
```bash
# تنظیم مجوزهای صحیح
sudo chown -R tek-push-khas:tek-push-khas /opt/tek-push-khas/uploads/
sudo chmod -R 755 /opt/tek-push-khas/uploads/
```

## امنیت

- فایروال خودکار پیکربندی می‌شود
- SSL رایگان با Let's Encrypt (در صورت وجود دامنه)
- پایگاه داده با رمز عبور قوی محافظت می‌شود
- session ها امن ذخیره می‌شوند

## پشتیبانی

- پروژه اصلی: [github.com/moha100h/tek-push-khas](https://github.com/moha100h/tek-push-khas)
- اسکریپت نصب: [github.com/moha100h/tek-push-khas-install](https://github.com/moha100h/tek-push-khas-install)

## مجوز

MIT License - استفاده آزاد برای مقاصد تجاری و شخصی