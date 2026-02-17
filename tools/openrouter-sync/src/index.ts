import OpenRouter from '@openrouter/sdk';
import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

type OpenRouterModel = {
  id: string;
  name?: string;
  architecture?: {
    output_modalities?: string[];
  };
};

type PopularSeed = {
  id: string;
  displayName: string;
  rank: number;
  tags: string[];
};

async function main() {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY is required');
  }

  const client = new OpenRouter({ apiKey });
  const response = await client.models.list();

  const models = ((response as { data?: OpenRouterModel[] }).data ?? [])
    .filter((model) => (model.architecture?.output_modalities ?? []).includes('image'))
    .sort((a, b) => a.id.localeCompare(b.id));

  const seeds: PopularSeed[] = models.slice(0, 20).map((model, index) => ({
    id: model.id,
    displayName: model.name ?? model.id,
    rank: index + 1,
    tags: ['auto-synced', 'image-capable'],
  }));

  const outputPath = resolve(
    process.cwd(),
    '../../Sources/AuroraStudioApp/Resources/popular_models.json',
  );

  await writeFile(outputPath, JSON.stringify(seeds, null, 2) + '\n', 'utf8');
  console.log(`Wrote ${seeds.length} entries to ${outputPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
