import 'dotenv/config';
import OpenAI from 'openai';

// Ensure .env at repo root was loaded
if (!process.env.OPENAI_API_KEY) {
  console.log('OPENAI_API_KEY not found in .env. Edit Sierra-Painting-v1/.env and set OPENAI_API_KEY=sk-...');
  process.exit(1);
}

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

(async () => {
  try {
    const response = await client.responses.create({
      model: 'gpt-4o-mini',
      input: 'Give me a single short sentence about paint.'
    });
    console.log(response.output_text || JSON.stringify(response));
  } catch (err) {
    console.error('OpenAI call failed:', err?.message || err);
  }
})();
