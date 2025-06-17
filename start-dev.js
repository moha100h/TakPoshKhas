#!/usr/bin/env node

// Development server starter that bypasses the TypeScript compilation issues
const { spawn } = require('child_process');

console.log('Starting development server...');

const server = spawn('node', ['server/simple-server.cjs'], {
  stdio: 'inherit',
  env: { ...process.env, NODE_ENV: 'development' }
});

server.on('error', (err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

server.on('close', (code) => {
  console.log(`Server exited with code ${code}`);
  process.exit(code);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  server.kill('SIGINT');
});

process.on('SIGTERM', () => {
  console.log('\nShutting down server...');
  server.kill('SIGTERM');
});