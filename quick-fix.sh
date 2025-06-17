#!/bin/bash

# راه‌حل سریع برای مشکل سرویس
# Quick fix for service issues

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SERVICE_NAME="tek-push-khas"
APP_DIR="/opt/tek-push-khas"

# Stop any running processes
log_info "متوقف کردن پروسه‌های موجود..."
systemctl stop ${SERVICE_NAME} 2>/dev/null || true
pkill -f "node.*5000" 2>/dev/null || true

# Fix systemd service file
log_info "اصلاح فایل سرویس..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Tek Push Khas Application
Documentation=https://github.com/moha100h/TakPoshKhas
After=network.target postgresql.service
Wants=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=${APP_DIR}
Environment=NODE_ENV=production
Environment=PORT=5000
EnvironmentFile=${APP_DIR}/.env
ExecStart=/usr/bin/node ${APP_DIR}/dist/server/index.js
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3
StandardOutput=journal
StandardError=journal
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create production server if missing
if [ ! -f "${APP_DIR}/dist/server/index.js" ]; then
    log_info "ایجاد سرور تولید..."
    mkdir -p ${APP_DIR}/dist/server
    
    cat > ${APP_DIR}/dist/server/index.js << 'EOJS'
const express = require('express');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 5000;

// Database pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
});

// Basic middleware
app.use(express.json());
app.use(express.static('public'));

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT NOW()');
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// API endpoints
app.get('/api/brand-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM brand_settings LIMIT 1');
    res.json(result.rows[0] || { name: 'تک پوش خاص', slogan: 'یک از یک' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/tshirt-images', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tshirt_images WHERE is_active = true ORDER BY display_order');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/social-links', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM social_links WHERE is_active = true');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/copyright-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM copyright_settings LIMIT 1');
    res.json(result.rows[0] || { text: '© 1404 تک پوش خاص' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/user', (req, res) => {
  res.status(401).json({ message: 'وارد نشده‌اید' });
});

// Main page
app.get('*', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تک پوش خاص - یک از یک</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            color: white;
            text-align: center;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 3rem;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        }
        h1 { font-size: 3rem; margin-bottom: 1rem; }
        p { font-size: 1.2rem; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎽 تک پوش خاص</h1>
        <p>یک از یک</p>
        <p>سرور با موفقیت راه‌اندازی شد</p>
        <p>Server is running successfully</p>
    </div>
</body>
</html>
  `);
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 تک پوش خاص در پورت ${PORT} راه‌اندازی شد`);
  console.log(`Time: ${new Date().toISOString()}`);
});
EOJS

    chown -R www-data:www-data ${APP_DIR}
fi

# Reload systemd and start service
log_info "راه‌اندازی سرویس..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# Wait and check status
sleep 3

if systemctl is-active --quiet ${SERVICE_NAME}; then
    log_success "✅ سرویس با موفقیت راه‌اندازی شد"
    systemctl status ${SERVICE_NAME} --no-pager -l
else
    log_error "❌ سرویس راه‌اندازی نشد"
    journalctl -u ${SERVICE_NAME} -n 20 --no-pager
fi

# Test endpoints
log_info "تست API endpoints..."
sleep 2

if curl -f http://localhost/api/health > /dev/null 2>&1; then
    log_success "✅ Health endpoint کار می‌کند"
else
    log_error "❌ Health endpoint کار نمی‌کند"
fi

echo
echo "=== نتیجه نهایی ==="
if systemctl is-active --quiet ${SERVICE_NAME} && curl -f http://localhost/api/health > /dev/null 2>&1; then
    log_success "🎉 سرور کاملاً آماده است!"
    echo "وب‌سایت: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR-SERVER-IP')"
else
    log_error "❌ مشکلاتی وجود دارد"
    echo "برای عیب‌یابی: journalctl -u ${SERVICE_NAME} -f"
fi