# documentation

## GIT
password git: token mac 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

## VPS
```bash 
ssh root@202.155.95.201 -p 2222
```

## Office 356
```bash
#username:a49769@msdn365.vip
#password:bismiLL4h100

#username:rifki.copilot@officeoriku.com
#password: bismiLL4h100

#username: rifki.copilot@orioffice365.com
```
## AI API GROQ
```
https://console.groq.com/keys
Bearer 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
```


## WA API TOKEN
```
EAAYXZAwSXsvgBRpg7jkUVOVga2Ufh6hdqK4IvojfM1OCs0F0bylwZBAdBWrFc9DCtX7iU1kDjH1iv4Pix3g2S9jJX6U98QY5rWGG5TDG2D8tWBjnMlZAwXHT7X6w7KIiGdV95IE8m87TK3qxpStP37aZCP5wRhqnmIRMfmsV2xslYWMiH3XX8gmvKUKtJeLoAD1nErRUYcxDULSngTVh2ZCDqfJ4QjeCHq6I5UU3A
```
## PIN WA REGISTER
```
358558
```
## FACEBOOK
```
https://business.facebook.com
```
## SHOPEE & TIKTOK OPEN PLATFORM
```
https://open.shopee.com/console/app
u:gelimbung@gmail.com
##
https://partner.tiktokshop.com/
u: gelimbung@gmail.com
p: vps
```
## QUICK REFERENCE N8N:
```
KakJumBOT Flow (n8n):
├─ Webhook Incoming (Evolution API → n8n)
├─ Validate & Format (sanitize input)
├─ Filter Valid Message (pastiin ada phone + message)
├─ Detect Intent (Groq llama-3.3-70b)
├─ Extract Intent JSON (parse Groq response)
├─ Get Session Context (Odoo API)
├─ Merge Message + Context (combine pesan + history)
├─ Prepare Response Data (format untuk routing)
├─ Route by Intent (Switch: daftar_harga / stok / order / default)
│  ├─ daftar_harga → Search Product → Generate Natural Reply
│  ├─ stok → Search Product → Generate Natural Reply
│  ├─ order → Save to Odoo → Generate Natural Reply
│  └─ default → Generate Natural Reply
├─ Send WhatsApp Reply (balik ke WA)
└─ (Optional logging ke Odoo chatbot_logs)

API Keys:
- Odoo Chatbot API: f46c076fc034b7330958d54e154e657283d3bfc6
- Groq API: (di Groq node, separate)
```
