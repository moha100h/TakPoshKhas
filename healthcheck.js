#!/usr/bin/env node

// Simple health check script for production deployment
const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/brand-settings',
  method: 'GET',
  timeout: 5000
};

const req = http.request(options, (res) => {
  if (res.statusCode === 200 || res.statusCode === 401) {
    console.log('✓ Server is healthy');
    process.exit(0);
  } else {
    console.log(`✗ Server returned ${res.statusCode}`);
    process.exit(1);
  }
});

req.on('error', (err) => {
  console.log(`✗ Server is not responding: ${err.message}`);
  process.exit(1);
});

req.on('timeout', () => {
  console.log('✗ Server timeout');
  req.destroy();
  process.exit(1);
});

req.end();