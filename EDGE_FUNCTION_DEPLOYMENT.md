# 📧 Edge Function Deployment Instructions

## Konfiguracja Edge Function dla wysyłania zaproszeń

### 1. Zainstaluj Supabase CLI

```bash
npm install -g supabase-cli
```

### 2. Zaloguj się do Supabase

```bash
supabase login
```

### 3. Połącz z projektem

```bash
supabase link --project-ref hbwnghrfhyikcywixjqn
```

### 4. Wdróż Edge Function

```bash
supabase functions deploy send-invitation-email
```

### 5. Ustaw environment variables

W Supabase Dashboard → Settings → Edge Functions → Environment Variables:

```
RESEND_API_KEY=re_jBEa4feF_Nvz6ETCQX397aUm2kjSDbmoc
```

### 6. Sprawdź deployment

Edge Function będzie dostępna pod:
```
https://hbwnghrfhyikcywixjqn.supabase.co/functions/v1/send-invitation-email
```

## Alternatywne metody deployment

### Metoda 1: Przez Supabase Dashboard

1. Przejdź do: Dashboard → Edge Functions → Create new function
2. Nazwa: `send-invitation-email`
3. Skopiuj kod z pliku `supabase/functions/send-invitation-email/index.ts`
4. Deploy

### Metoda 2: Ręczne wdrożenie

Jeśli Supabase CLI nie działa, można:

1. Utworzyć Edge Function przez Dashboard
2. Skopiować kod TypeScript
3. Ustawić RESEND_API_KEY w environment variables
4. Przetestować endpoint

## Test Edge Function

```bash
curl -X POST \
  'https://hbwnghrfhyikcywixjqn.supabase.co/functions/v1/send-invitation-email' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "to": "test@example.com",
    "projectName": "Test Project",
    "role": "VIEW_ONLY",
    "invitationToken": "test-token",
    "inviterEmail": "admin@flowcraft.bronskipatryk.pl",
    "customMessage": "Welcome to our project!",
    "siteUrl": "https://flowcraft.bronskipatryk.pl"
  }'
```

## Troubleshooting

### CORS Error
Edge Function automatycznie obsługuje CORS. Jeśli pojawią się błędy CORS, sprawdź czy:
- Edge Function jest prawidłowo wdrożona
- Authorization header jest ustawiony
- Content-Type jest application/json

### Environment Variables
Sprawdź w Dashboard → Settings → Edge Functions czy RESEND_API_KEY jest ustawiony.

### Logs
Sprawdź logi Edge Function w Dashboard → Edge Functions → Logs.

## Status

✅ **Edge Function kod przygotowany**
✅ **Frontend zaktualizowany**
⏳ **Wymaga ręcznego wdrożenia w Supabase Dashboard**

Po wdrożeniu Edge Function system zaproszeń będzie w pełni funkcjonalny na produkcji.