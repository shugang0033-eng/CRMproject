import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 5180,
    open: false,
    // 后端由 Spring + MyBatis 提供；如需换端口，设置环境变量 CRM_API_TARGET 即可
    proxy: {
      '/api': {
        target: process.env.CRM_API_TARGET || 'http://127.0.0.1:8080',
        changeOrigin: true
      }
    }
  }
})

