import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import canDirective from './directives/can'
import './styles/global.css'

createApp(App).use(router).use(canDirective).mount('#app')
