import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { createHtmlPlugin } from "vite-plugin-html";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    svelte(),
    createHtmlPlugin({
      pages: [
        {
          entry: "src/pages/page1.ts",
          template: "page1.html",
          filename: "page1.html",
        },
        {
          entry: "src/pages/page2.ts",
          template: "page2.html",
          filename: "page2.html",
        },
      ],
    }),
  ],
  build: {
    rollupOptions: {
      input: {
        page1: "src/page1/page1.ts",
        page2: "src/page2/page2.ts",
      },
    },
  },
});
