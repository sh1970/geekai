import vue from '@vitejs/plugin-vue'
import path from 'path'
import { defineConfig, loadEnv } from 'vite'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd())
  const apiHost = env.VITE_API_HOST || 'http://localhost:5678'

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    css: {
      preprocessorOptions: {
        stylus: {
          additionalData: `@import "@/assets/css/index.styl";`,
        },
      },
    },
    optimizeDeps: {
      include: ['stylus'],
    },
    server: {
      port: 8888,
      ...(process.env.NODE_ENV === 'development'
        ? {
            proxy: {
              '/api': {
                target: apiHost,
                changeOrigin: true,
                ws: true,
              },
              '/static/upload/': {
                target: apiHost,
                changeOrigin: true,
              },
            },
          }
        : {}),
    },
  }
})
