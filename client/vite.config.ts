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
          entry: "src/pages/document.ts",
          template: "document.html",
          filename: "document.html",
        },
        {
          entry: "src/pages/home.ts",
          template: "home.html",
          filename: "home.html",
        },
      ],
    }),
  ],
  build: {
    rollupOptions: {
      input: {
        document: "src/document/document.ts",
        home: "src/home/home.ts",
      },
    },
  },
});
