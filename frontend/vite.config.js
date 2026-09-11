import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    // Puerto fijo: debe coincidir con callback_urls en Cognito
    port: 5173,
    strictPort: true,
  },
})
