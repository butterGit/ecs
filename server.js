import express from 'express';

const app = express();
const port = Number(process.env.PORT) || 3000;

app.use(express.json());

const items = [
  { id: 1, name: 'Learn Docker' },
  { id: 2, name: 'Deploy to AWS ECS Fargate' },
];

app.get('/', (_req, res) => {
  res.json({
    message: 'Docker + Node + AWS learning app',
    endpoints: ['/health', '/items'],
  });
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.get('/items', (_req, res) => {
  res.json(items);
});

app.post('/items', (req, res) => {
  const name = req.body?.name;
  if (typeof name !== 'string' || name.trim() === '') {
    return res.status(400).json({ error: 'name is required' });
  }

  const item = { id: items.length + 1, name: name.trim() };
  items.push(item);
  res.status(201).json(item);
});

app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
