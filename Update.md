# Rozbudowa Projektu: System Zarządzania Procesami z Kontrolą Dostępu i Kalendarzem

## Główne funkcjonalności do dodania

### 1. System współdzielenia projektów i kontroli dostępu
**Wymagania:**
- Właściciel projektu może zapraszać użytkowników (przez email z Resend)
- Trzy poziomy dostępu:
  - **FULL_ACCESS**: pełny dostęp do wszystkiego
  - **EDIT_ACCESS**: możliwość edycji i dodawania procesów
  - **VIEW_ONLY**: tylko podgląd, brak możliwości edycji diagramu

**Struktury bazy danych:**
- przeanalizuj jak to zrobić najlepiej

### 2. System kalendarzowy z dnami roboczymi
**Koncepcja WD (Working Days):**
- WD 1 = pierwszy dzień roboczy miesiąca
- WD-1 = ostatni dzień roboczy poprzedniego miesiąca
- Due time = godzina terminu wykonania
- System automatycznie mapuje procesy na konkretne daty i godziny w kalendarzu daje możliwość przełączania się pomiędzy miesiącami co automatycznie modyfikuje odpowiedni termin względem miesiąca

**Funkcjonalności:**
- Generowanie kalendarza dni roboczych dla wybranego miesiąca
- Automatyczne dopasowywanie procesów do konkretnych dat
- Uwzględnianie świąt i weekendów
- Lista procesów segregowana jest według terminu wykonania, "Full_Access" i Edit Access ma możliwość przełączenia wcześniejszych miesięcu w celu weryfikacji danych historycznych lub kolejnych miesięcy.

### 3. System trackingu wykonania zadań
**Mechanizm odklikiwania:**
- Użytkownicy mogą oznaczać procesy jako wykonane
- Możliwość oznaczenia z opóźnieniem (dla osób odklikujących później)
- Automatyczne oznaczanie jako "niewykonane" po przekroczeniu terminu aż do momentu podjęcia działania
- Możliwość manualnego oznaczenia jako niewykonane konieczne podanie powodu
- Możliwość dodania komentarza/powodu opóźnienia

**Statusy procesów:**
- `PENDING` - oczekujące
- `COMPLETED_ON_TIME` - wykonane na czas
- `COMPLETED_LATE` - wykonane z opóźnieniem
- `OVERDUE` - przekroczony termin, niewykonane
- `DELAYED_WITH_REASON` - opóźnione z podanym powodem

### 4. Wizualizacja statusów na diagramie
**Efekty wizualne:**
- Procesy wykonane na czas: coś pasującego do desing diagramu metaliczna zielona poświata + zielony ptaszek lub zaproponuj coś
- Procesy po terminie: czerwone oznaczenie
- Procesy opóźnione z powodem: pomarańczowe/żółte oznaczenie
- Procesy oczekujące: standardowy wygląd

## Techniczne wymagania

### Baza danych (Supabase)
- Rozszerz istniejące tabele o nowe kolumny
- Rozszerzenie tabeli o osobę odpowiedzialną za proces można przypisać imię i nazwisko lub email lub kilka osób
- Dodaj tabele dla członkostwa w projektach i zaproszeń
- Zaimplementuj RLS (Row Level Security) dla kontroli dostępu

### Backend/API
- Endpointy dla zarządzania członkostwem projektu
- Logika kalendarza dni roboczych
- Système trackingu statusów procesów
- Automatyczne zadania (cron jobs) do oznaczania procesów po terminie

### Frontend
- Interfejs zapraszania użytkowników
- Panel oznaczania procesów jako wykonane
- Ulepszona wizualizacja diagramu z statusami
- Projects zostawmy ale przeróbmy sheets żeby pasował jak ktoś tylko będzie chciał dodać sobie tam procesy i zależności budować ale też żeby mógł wykorzystać to jako checklistę

### Integracje
- Resend: wysyłanie zaproszeń do projektów
- Powiadomienia o zbliżających się terminach
- Raporty dla zarządu

## Priorytety implementacji
- Przeanalizuj jak to zrobić

## Pytania do rozważenia
- Jak obsługiwać strefy czasowe dla zespołów rozproszonych?
- Czy potrzebujemy historii zmian statusów procesów?
- Czy dodać możliwość komentarzy/załączników do procesów? Chciałbym żeby tak było
- Diagram powinien odzwierciedlać statusy w czasie rzeczywistym, umożliwiając zarządowi szybką analizę.
- Wszystko powinno być kompatybilne z Supabase jako backendem (auth, db, invites).
- Zastanów się też, jak zaprojektować strukturę tabel w Supabase, żeby obsłużyć role, statusy procesów, komentarze i relacje między użytkownikami a projektami/procesami.

**Proszę rozpocznij od analizy istniejącej struktury projektu i zaproponuj szczegółowy plan.**