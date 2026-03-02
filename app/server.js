const express = require("express");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

// Environment variables injected at runtime (ECS later)
const DB_HOST = process.env.DB_HOST;
const DB_PORT = Number(process.env.DB_PORT || 5432);
const DB_NAME = process.env.DB_NAME || "fintech";
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;

const pool = new Pool({
  host: DB_HOST,
  port: DB_PORT,
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

app.get("/health", async (_req, res) => {
  // ALB health check hits this endpoint
  res.status(200).json({ status: "ok" });
});

app.get("/dbcheck", async (_req, res) => {
  // Simple DB connectivity check (useful for debugging)
  try {
    const result = await pool.query("SELECT NOW() as now");
    res.status(200).json({ db: "ok", now: result.rows[0].now });
  } catch (err) {
    res.status(500).json({ db: "fail", error: String(err.message || err) });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => {
  console.log(`API listening on port ${port}`);
});
console.log("DB SSL:", "ENABLED");
