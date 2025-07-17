# 📋 Plan Rozwoju Systemu FlowCraft - Checklista z Historią Miesięczną

## 🎯 Cel Projektu

Rozbudowa systemu FlowCraft o funkcjonalność checklisty procesów z pełną historią wykonania dla każdego miesiąca. System ma umożliwiać:

1. **Checklistę procesów** - szybkie oznaczanie procesów jako wykonanych/opóźnionych
2. **Historię miesięczną** - przechowywanie informacji o wykonaniu dla każdego miesiąca osobno
3. **Analizę historyczną** - przeglądanie danych z poprzednich miesięcy
4. **Diagram miesięczny** - wizualizację statusów dla wybranego miesiąca

## 📊 Analiza Obecnego Stanu

### ✅ Co już mamy:

- Struktura bazy danych: tabele `projects`, `sheets`, `processes`, `process_status_history`
- Zmiana statusu procesu (PENDING, COMPLETED_ON_TIME, COMPLETED_LATE, OVERDUE, DELAYED_WITH_REASON)
- Przypisywanie procesów do użytkowników
- Obliczanie deadline na podstawie working day
- Selektory miesiąca/roku w widoku procesów
- Tabela procesów z inline editing, modal do zmiany statusu, kolorowe oznaczenia statusów, diagram flow

### ❌ Czego brakuje:

- Historia miesięczna (status per miesiąc)
- Intuicyjny interfejs checklisty
- Filtrowanie historyczne
- Raportowanie

## 🏗️ Architektura Rozwiązania

### 1. Model Danych - Nowa Tabela

```sql
CREATE TABLE public.process_executions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    status VARCHAR(50) CHECK (status IN ('PENDING', 'COMPLETED_ON_TIME', 'COMPLETED_LATE', 'OVERDUE', 'DELAYED_WITH_REASON')),
    completed_at TIMESTAMP WITH TIME ZONE,
    completed_by UUID REFERENCES auth.users(id),
    completion_note TEXT,
    deadline_date DATE,
    deadline_time TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT process_executions_unique UNIQUE (process_id, year, month)
);
```

### 2. Migracja Danych

```sql
INSERT INTO public.process_executions (process_id, year, month, status, completed_at, completion_note)
SELECT 
    id as process_id,
    EXTRACT(YEAR FROM COALESCE(completed_at, NOW())) as year,
    EXTRACT(MONTH FROM COALESCE(completed_at, NOW())) as month,
    status,
    completed_at,
    completion_note
FROM public.processes
WHERE status != 'PENDING';
```

## 🛠️ Plan Implementacji

### Faza 1: Backend - Struktura Danych

- Utworzenie tabeli `process_executions`
- Indeksy, constraints, RLS policies
- API: pobieranie, aktualizacja, raportowanie wykonań

### Faza 2: UI Checklisty

- Nowy widok checklisty (przełącznik widoku: tabela/checklista/diagram)
- Karty procesów z quick actions (wykonane/opóźnione)
- Wizualna timeline postępu

### Faza 3: Historia i Filtrowanie

- Rozbudowa selektorów month/year
- Tryb tylko do odczytu dla przeszłych miesięcy
- Statystyki wykonania

### Faza 4: Integracja z Diagramem

- Diagram dla wybranego miesiąca (kolorowanie node'ów wg statusu)
- Timeline view (Gantt-like)

### Faza 5: Raportowanie

- Dashboard wykonania, wykres trendu, heatmapa miesięcy
- Export CSV/PDF

## 🎨 UI/UX Improvements

- Grid checklisty, karty z szybkim oznaczaniem, progress bar
- Tryb mobilny, bulk operations, komentarze

## 🔄 Workflow Użytkownika

- Codzienne wykonywanie: checklista, szybkie oznaczanie, progress bar
- Analiza historyczna: wybór miesiąca, raport, porównania
- Planowanie: przyszłe miesiące, przypisania, notatki

## 🚀 Kolejność Implementacji

1. Tabela `process_executions` i migracja danych
2. API i backend
3. UI checklisty
4. Historia i statystyki
5. Integracja z diagramem i raportowanie

## 🎯 Kluczowe Funkcjonalności

- Historia wykonania per miesiąc
- Checklist UI z quick actions
- Filtrowanie po miesiącach
- Status preservation między miesiącami

---

**Ten plan zapewnia kompleksowe rozwiązanie dla systemu checklisty z pełną historią miesięczną, zachowując prostotę użytkowania i wydajność systemu.** 