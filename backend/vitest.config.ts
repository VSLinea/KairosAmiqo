import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['test/**/*.test.ts'],
    // Run tests sequentially in single thread to preserve singleton state
    pool: 'threads',
    poolOptions: {
      threads: {
        singleThread: true,
      },
    },
    // Shorter timeouts - tests should be fast
    testTimeout: 5000,
    hookTimeout: 10000,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'dist/',
        'test/',
        '**/*.test.ts',
      ],
    },
  },
});
