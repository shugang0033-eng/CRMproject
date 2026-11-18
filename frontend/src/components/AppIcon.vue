<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    :stroke-width="strokeWidth"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
    v-html="paths[name] || paths.dot"
  />
</template>

<script setup>
const props = defineProps({
  name: { type: String, default: 'dot' },
  size: { type: [Number, String], default: 16 },
  strokeWidth: { type: [Number, String], default: 1.7 }
})

const paths = {
  dot: '<circle cx="12" cy="12" r="3" />',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none"/>',
  users: '<path d="M16 20v-1.5a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4V20"/><circle cx="9.5" cy="7.5" r="3.2"/><path d="M17 4.3a3.2 3.2 0 0 1 0 6.2"/><path d="M19.5 20v-1.4a3.6 3.6 0 0 0-2.6-3.4"/>',
  user: '<path d="M19 20v-1.6a4.4 4.4 0 0 0-4.4-4.4H9.4A4.4 4.4 0 0 0 5 18.4V20"/><circle cx="12" cy="7.6" r="3.6"/>',
  file: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 17h4"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.7 1.7 0 0 0-1.87-.34 1.7 1.7 0 0 0-1.03 1.56V21a2 2 0 1 1-4 0v-.11a1.7 1.7 0 0 0-1.11-1.56 1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.7 1.7 0 0 0 .34-1.87 1.7 1.7 0 0 0-1.56-1.03H3a2 2 0 1 1 0-4h.11a1.7 1.7 0 0 0 1.56-1.11 1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.7 1.7 0 0 0 1.87.34H9a1.7 1.7 0 0 0 1.03-1.56V3a2 2 0 1 1 4 0v.11a1.7 1.7 0 0 0 1.03 1.56 1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.7 1.7 0 0 0-.34 1.87V9a1.7 1.7 0 0 0 1.56 1.03H21a2 2 0 1 1 0 4h-.11a1.7 1.7 0 0 0-1.49 1z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.6-3.6"/>',
  bell: '<path d="M18 9a6 6 0 1 0-12 0c0 5-2 6-2 6h16s-2-1-2-6"/><path d="M10.3 20a2 2 0 0 0 3.4 0"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  minus: '<path d="M5 12h14"/>',
  'chevron-down': '<path d="m6 9 6 6 6-6"/>',
  'chevron-up': '<path d="m6 15 6-6 6 6"/>',
  'chevron-right': '<path d="m9 6 6 6-6 6"/>',
  'chevron-left': '<path d="m15 6-6 6 6 6"/>',
  close: '<path d="M18 6 6 18M6 6l12 12"/>',
  check: '<path d="m20 6-11 11-5-5"/>',
  'check-circle': '<circle cx="12" cy="12" r="9"/><path d="m8.5 12 2.5 2.5 4.5-5"/>',
  trash: '<path d="M4 7h16"/><path d="M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/><path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12"/><path d="M10 11v6M14 11v6"/>',
  edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
  filter: '<path d="M4 5h16l-6.4 7.6V19l-3.2 1.6v-8z"/>',
  download: '<path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M8 3v4M16 3v4M3 10h18"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>',
  phone: '<path d="M5 3h3l1.6 4-2 1.4a12 12 0 0 0 6 6l1.4-2 4 1.6v3a2 2 0 0 1-2.2 2A16.5 16.5 0 0 1 3 5.2 2 2 0 0 1 5 3z"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3.5 6.5 8.5 6 8.5-6"/>',
  lock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
  logout: '<path d="M9 21H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
  'trend-up': '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
  'trend-down': '<path d="M3 7l6 6 4-4 8 8"/><path d="M15 17h6v-6"/>',
  'arrow-up': '<path d="M12 19V5"/><path d="m6 11 6-6 6 6"/>',
  'arrow-down': '<path d="M12 5v14"/><path d="m6 13 6 6 6-6"/>',
  'arrow-right': '<path d="M4 12h15"/><path d="m13 6 6 6-6 6"/>',
  building: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2"/>',
  wallet: '<path d="M20 7H6a2 2 0 0 1 0-4h12v4"/><path d="M4 5v14a2 2 0 0 0 2 2h14V7"/><circle cx="16.5" cy="14" r="1.2" fill="currentColor" stroke="none"/>',
  receipt: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>',
  box: '<path d="m12 3 8 4.5v9L12 21l-8-4.5v-9z"/><path d="m4 7.5 8 4.5 8-4.5"/><path d="M12 12v9"/>',
  briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/><path d="M3 12h18"/>',
  layers: '<path d="m12 3 9 5-9 5-9-5z"/><path d="m3 13 9 5 9-5"/>',
  shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="m9 12 2 2 4-4"/>',
  chart: '<path d="M3 21h18"/><rect x="5" y="12" width="3.6" height="6" rx="1"/><rect x="10.2" y="8" width="3.6" height="10" rx="1"/><rect x="15.4" y="4" width="3.6" height="14" rx="1"/>',
  inbox: '<path d="M4 13h4l1.5 2.5h5L16 13h4"/><path d="M5.5 4h13l1.5 9v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-5z"/>',
  'map-pin': '<path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11z"/><circle cx="12" cy="10" r="2.6"/>',
  eye: '<path d="M2.5 12S6 5.8 12 5.8 21.5 12 21.5 12 18 18.2 12 18.2 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
  more: '<circle cx="5" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.4" fill="currentColor" stroke="none"/>',
  key: '<circle cx="8" cy="14" r="4"/><path d="m11 11 8-8 3 3-2 2-2-2-2 2"/>',
  refresh: '<path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/>',
  sparkle: '<path d="M12 3v5M12 16v5M4.5 12h5M14.5 12h5"/><path d="M7 7l2.4 2.4M14.6 14.6 17 17M17 7l-2.4 2.4M9.4 14.6 7 17"/>',
  'building-2': '<path d="M3 21h18"/><path d="M6 21V6l6-3 6 3v15"/><path d="M10 21v-4h4v4"/>',
  flag: '<path d="M5 21V4"/><path d="M5 4h11l-1.6 4L16 12H5z"/>',
  star: '<path d="m12 4 2.4 5 5.6.8-4 4 .9 5.6-4.9-2.6L7.1 19l.9-5.6-4-4L9.6 9z"/>',
  camera: '<path d="M4.5 8h2.8l1.5-2.3a1 1 0 0 1 .8-.45h4.8a1 1 0 0 1 .8.45L16.7 8h2.8a1.5 1.5 0 0 1 1.5 1.5v8.5a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9.5A1.5 1.5 0 0 1 4.5 8z"/><circle cx="12" cy="13.2" r="3.3"/>',
  upload: '<path d="M12 16V4"/><path d="m7 9 5-5 5 5"/><path d="M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>',
  monitor: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8"/><path d="M12 16v4"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3.4 9.2h17.2M3.4 14.8h17.2"/><path d="M12 3a14 14 0 0 1 0 18 14 14 0 0 1 0-18z"/>',
  'eye-off': '<path d="M4 4l16 16"/><path d="M9.8 5.6A9.7 9.7 0 0 1 12 5.3c6 0 9.5 6.7 9.5 6.7a17.6 17.6 0 0 1-3.4 4.1"/><path d="M6.4 8A17.4 17.4 0 0 0 2.5 12S6 18.7 12 18.7a9.6 9.6 0 0 0 3.6-.7"/><path d="M10.1 10.2a2.7 2.7 0 0 0 3.8 3.8"/>'
}
</script>
