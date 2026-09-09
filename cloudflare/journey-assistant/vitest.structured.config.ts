import { defineConfig } from 'vitest/config';

// Artifact checks need the host filesystem; the Worker pool uses virtual FS.
export default defineConfig({
  test: { environment: 'node', include: ['test/structured*.test.ts'] },
});
