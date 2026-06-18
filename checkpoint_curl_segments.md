# Chatbot API Curl Checkpoints

Jalankan variable ini dulu di terminal yang sama:

```bash
export BASE_URL="http://localhost:8069"
export DB="odoo18_staging"
export API_KEY="f46c076fc034b7330958d54e154e667283d3bfc6"
export PHONE="6281234567890"
```

## 1. Cek Unauthorized

```bash
curl -i -X POST "$BASE_URL/api/chatbot/product?db=$DB" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: bad-key" \
  --data '{"keyword":"Sukari","phone":"6281234567890"}'
```

## 2. Create Chatbot Log

```bash
curl -i -X POST "$BASE_URL/api/chatbot/log?db=$DB" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  --data '{"msgId":"curl-check-001","phone":"6281234567890","message":"cek harga Sukari","intent":"harga","product":"Sukari","reply":"test curl"}'
```

## 3. Cek Idempotency Log

```bash
curl -i -X POST "$BASE_URL/api/chatbot/log?db=$DB" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  --data '{"msgId":"curl-check-001","phone":"6281234567890","message":"duplicate test"}'
```

## 4. Product Search

```bash
curl -i -X POST "$BASE_URL/api/chatbot/product?db=$DB" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  --data '{"keyword":"Sukari","phone":"6281234567890"}'
```

## 5. Quote

```bash
curl -i -X POST "$BASE_URL/api/chatbot/quote?db=$DB" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  --data '{"items":[{"product_id":884,"query":"Sukari Premium 500Gr","qty":2}]}'
```

## 6. Create Order

```bash
curl -i -X POST "$BASE_URL/api/chatbot/order?db=$DB" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  --data '{"phone":"6281234567890","name":"Checkpoint Curl","street":"Jl. Test No. 1","idempotency_key":"curl-order-001","cart":[{"product_id":884,"qty":1}]}'
```

## 7. Store Info

```bash
curl -i -X GET "$BASE_URL/api/chatbot/store-info?db=$DB" \
  -H "X-API-Key: $API_KEY"
```

## 8. Login Odoo untuk Verify Model

```bash
curl -i -c /tmp/odoo-chatbot-cookie.txt \
  -X POST "$BASE_URL/web/session/authenticate" \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","params":{"db":"odoo18_staging","login":"admin","password":"admin"}}'
```

## 9. Verify chatbot.log

```bash
curl -i -b /tmp/odoo-chatbot-cookie.txt \
  -X POST "$BASE_URL/web/dataset/call_kw/chatbot.log/search_read" \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"call","params":{"model":"chatbot.log","method":"search_read","args":[[["phone","=","6281234567890"]]],"kwargs":{"fields":["id","message_id","phone","message","intent","product","reply","response","status","create_date"],"limit":5,"order":"create_date desc"}}}'
```

## 10. Verify chatbot.session

```bash
curl -i -b /tmp/odoo-chatbot-cookie.txt \
  -X POST "$BASE_URL/web/dataset/call_kw/chatbot.session/search_read" \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"call","params":{"model":"chatbot.session","method":"search_read","args":[[["phone","=","6281234567890"]]],"kwargs":{"fields":["id","phone","last_product","last_intent","last_interaction"],"limit":5,"order":"last_interaction desc"}}}'
```
