-- ==========================================
-- ROLLBACK: Usunięcie tabeli process_executions
-- Data: 2025-01-13
-- Opis: Plik rollback do cofnięcia zmian z process_executions_migration.sql
-- UWAGA: To jest nieodwracalne usunięcie danych!
-- ==========================================

-- 1. Upewnij się, że chcesz usunąć całą tabelę process_executions
-- UWAGA: To usunie wszystkie dane historyczne wykonań procesów!

-- Wyświetl liczbę rekordów które zostaną usunięte
DO $$
DECLARE
    record_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO record_count FROM public.process_executions;
    RAISE NOTICE 'UWAGA: Usuwanie % rekordów z tabeli process_executions', record_count;
    RAISE NOTICE 'To działanie jest nieodwracalne!';
END $$;

-- 2. Usuń trigger
DROP TRIGGER IF EXISTS trigger_process_executions_updated_at ON public.process_executions;

-- 3. Usuń funkcję trigger
DROP FUNCTION IF EXISTS update_process_executions_updated_at();

-- 4. Usuń funkcje pomocnicze
DROP FUNCTION IF EXISTS get_process_executions_for_month(UUID, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS update_process_execution_status(UUID, INTEGER, INTEGER, VARCHAR(50), TEXT, UUID);

-- 5. Usuń polityki RLS
DROP POLICY IF EXISTS "process_executions_access_policy" ON public.process_executions;

-- 6. Usuń indeksy (będą automatycznie usunięte wraz z tabelą, ale dla pewności)
DROP INDEX IF EXISTS idx_process_executions_process_id;
DROP INDEX IF EXISTS idx_process_executions_year_month;
DROP INDEX IF EXISTS idx_process_executions_status;
DROP INDEX IF EXISTS idx_process_executions_completed_by;
DROP INDEX IF EXISTS idx_process_executions_deadline_date;

-- 7. Usuń tabelę
DROP TABLE IF EXISTS public.process_executions CASCADE;

-- 8. Sprawdź czy tabela została usunięta
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'process_executions') THEN
        RAISE NOTICE 'Tabela process_executions została pomyślnie usunięta';
    ELSE
        RAISE EXCEPTION 'Błąd: Tabela process_executions nadal istnieje!';
    END IF;
END $$;

-- Koniec rollback