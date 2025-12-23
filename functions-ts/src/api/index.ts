import express from 'express';
import { healthRouter } from './routes/health';
import { uploadRouter } from './routes/upload';
import { authRouter } from './routes/auth';

const app = express();

// Middleware
app.use(express.json());

// CORS middleware
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  next();
});

// Routes
app.use('/health', healthRouter);
app.use('/upload', uploadRouter);
app.use('/auth', authRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

export { app };
