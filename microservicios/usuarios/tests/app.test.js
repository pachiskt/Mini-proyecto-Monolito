const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

afterAll(async () => {
  await pool.end();
});

describe('Pruebas de Usuarios', () => {
  test('GET /health debe responder correctamente', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.body.service).toBe('usuarios');
  });

  test('GET /usuarios debe devolver una lista', async () => {
    const response = await request(app).get('/usuarios');
    expect(response.statusCode).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
    expect(response.body.length).toBeGreaterThan(0);
  });

  test('GET /usuarios/:id debe devolver un usuario existente', async () => {
    const response = await request(app).get('/usuarios/1');
    expect(response.statusCode).toBe(200);
    expect(response.body.id).toBe(1);
  });

  test('GET /usuarios/:id debe responder 404', async () => {
    const response = await request(app).get('/usuarios/9999');
    expect(response.statusCode).toBe(404);
  });
});
