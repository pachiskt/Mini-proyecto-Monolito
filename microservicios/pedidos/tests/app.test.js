const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

afterAll(async () => {
  await pool.end();
});

describe('Pruebas de Pedidos', () => {
  test('GET /health debe responder correctamente', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.body.service).toBe('pedidos');
  });

  test('GET /pedidos debe devolver una lista', async () => {
    const response = await request(app).get('/pedidos');
    expect(response.statusCode).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
    expect(response.body.length).toBeGreaterThanOrEqual(0);
  });

  test('POST /pedidos debe crear un pedido', async () => {
    const response = await request(app)
      .post('/pedidos')
      .send({ usuario_id: 1, producto_id: 1, cantidad: 2 });
    expect(response.statusCode).toBe(201);
    expect(response.body.id).toBeDefined();
  });

  test('POST /pedidos debe fallar si usuario no existe', async () => {
    const response = await request(app)
      .post('/pedidos')
      .send({ usuario_id: 9999, producto_id: 1, cantidad: 1 });
    expect(response.statusCode).toBe(400);
    expect(response.body.error).toBe('El usuario o producto indicado no existe');
  });

  test('POST /pedidos debe fallar si producto no existe', async () => {
    const response = await request(app)
      .post('/pedidos')
      .send({ usuario_id: 1, producto_id: 9999, cantidad: 1 });
    expect(response.statusCode).toBe(400);
    expect(response.body.error).toBe('El usuario o producto indicado no existe');
  });
});
