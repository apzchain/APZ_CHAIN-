# چک‌لیست تست نسخه نصب‌شده روی سرور | APZ Dashboard

این فایل برای اطمینان از اجرای صحیح پروژه روی VPS طراحی شده است.

## ✅ بررسی سرویس‌ها با PM2

```bash
pm2 list
pm2 logs apz-api
pm2 logs apz-web
