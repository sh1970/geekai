import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
  server: {
    port: 8888,
    proxy: {
      '/api': {
        target: process.env.VUE_APP_API_HOST || 'http://localhost:8080', // Fallback if env var is not set
        changeOrigin: true,
        ws: true,
      },
      '/static/upload/': {
        target: process.env.VUE_APP_API_HOST || 'http://localhost:8080', // Fallback if env var is not set
        changeOrigin: true,
      },
    },
  },
});
