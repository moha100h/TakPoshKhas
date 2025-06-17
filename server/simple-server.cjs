const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 5000;

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT NOW()');
    res.json({ 
      status: 'ok', 
      timestamp: new Date().toISOString(),
      database: 'connected'
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'error', 
      message: 'Database connection failed' 
    });
  }
});

// Brand settings
app.get('/api/brand-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM brand_settings ORDER BY id LIMIT 1');
    const data = result.rows[0] || {
      name: 'تک پوش خاص',
      slogan: 'یک از یک',
      description: 'برند پیشرو در طراحی تی‌شرت'
    };
    res.json(data);
  } catch (error) {
    console.error('Brand settings error:', error);
    res.json({
      name: 'تک پوش خاص',
      slogan: 'یک از یک',
      description: 'برند پیشرو در طراحی تی‌شرت'
    });
  }
});

// T-shirt images
app.get('/api/tshirt-images', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM tshirt_images 
      WHERE is_active = true 
      ORDER BY display_order ASC, id ASC
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('T-shirt images error:', error);
    res.json([]);
  }
});

// Social links
app.get('/api/social-links', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM social_links 
      WHERE is_active = true 
      ORDER BY id ASC
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Social links error:', error);
    res.json([]);
  }
});

// Copyright settings
app.get('/api/copyright-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM copyright_settings ORDER BY id LIMIT 1');
    const data = result.rows[0] || {
      text: '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.'
    };
    res.json(data);
  } catch (error) {
    console.error('Copyright settings error:', error);
    res.json({
      text: '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.'
    });
  }
});

// About content
app.get('/api/about-content', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM about_content ORDER BY id LIMIT 1');
    const data = result.rows[0] || {
      title: 'درباره ما',
      content: 'برند پیشرو در طراحی تی‌شرت'
    };
    res.json(data);
  } catch (error) {
    console.error('About content error:', error);
    res.json({
      title: 'درباره ما',
      content: 'برند پیشرو در طراحی تی‌شرت'
    });
  }
});

// User endpoint (not authenticated)
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
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', 'Vazir', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            text-align: center;
            line-height: 1.6;
        }
        .container {
            max-width: 600px;
            padding: 3rem 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            backdrop-filter: blur(15px);
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .logo { font-size: 3.5rem; margin-bottom: 1rem; font-weight: bold; }
        .slogan { font-size: 1.8rem; margin-bottom: 2rem; opacity: 0.9; }
        .description { font-size: 1.1rem; margin-bottom: 2rem; opacity: 0.8; }
        .status { 
            background: rgba(46, 204, 113, 0.2);
            padding: 1.5rem;
            border-radius: 15px;
            margin-top: 2rem;
            border: 1px solid rgba(46, 204, 113, 0.3);
        }
        .status h3 { margin-bottom: 1rem; color: #2ecc71; }
        @media (max-width: 768px) {
            .logo { font-size: 2.5rem; }
            .slogan { font-size: 1.4rem; }
            .container { padding: 2rem 1rem; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🎽 تک پوش خاص</div>
        <div class="slogan">یک از یک</div>
        <div class="description">
            برند پیشرو در طراحی تی‌شرت های منحصر به فرد<br>
            با ترکیب خلاقیت و کیفیت، محصولاتی بی‌نظیر ارائه می‌دهیم
        </div>
        
        <div class="status">
            <h3>سرور با موفقیت راه‌اندازی شد</h3>
            <p>وب‌سایت آماده ارائه خدمات است</p>
            <p>تمامی API endpoints فعال هستند</p>
        </div>
    </div>
    
    <script>
        // Health check
        fetch('/api/health')
            .then(response => response.json())
            .then(data => {
                console.log('Server status:', data);
            })
            .catch(error => {
                console.error('Connection error:', error);
            });
    </script>
</body>
</html>
  `);
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 تک پوش خاص Server running on port ${PORT}`);
  console.log(`📅 ${new Date().toISOString()}`);
  console.log(`🔗 http://localhost:${PORT}`);
});