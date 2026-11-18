<template>
  <router-view v-slot="{ Component }">
    <component :is="Component" />
  </router-view>
</template>

<script setup>
// 根组件：只负责渲染路由出口，布局由 AppLayout 承载
</script>
