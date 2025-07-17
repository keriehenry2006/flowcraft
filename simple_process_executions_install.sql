-- ==========================================
-- PROSTA INSTALACJA: Process Executions (Bez Cleanup)
-- Data: 2025-01-13
-- Opis: Tworzy system od zera, ignorując istniejące obiekty
-- ==========================================

-- 1. Sprawdź stan i cleanup tylko tego co istnieje
DO $$
BEGIN
    -- Usuń funkcje jeśli istnieją
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_process_executions_for_month') THEN
        DROP FUNCTION get_process_executions_for_month(UUID, INTEGER, INTEGER);
        RAISE NOTICE 'Usunięto funkcję get_process_executions_for_month';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_process_execution_status') THEN
        DROP FUNCTION update_process_execution_status(UUID, INTEGER, INTEGER, VARCHAR(50), TEXT, UUID);
        RAISE NOTICE 'Usunięto funkcję update_process_execution_status';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_process_executions_updated_at') THEN
        DROP FUNCTION update_process_executions_updated_at();
        RAISE NOTICE 'Usunięto funkcję update_process_executions_updated_at';
    END IF;
    
    -- Usuń tabelę jeśli istnieje
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'process_executions') THEN
        DROP TABLE public.process_executions CASCADE;
        RAISE NOTICE 'Usunięto tabelę process_executions';
    END IF;
    
    RAISE NOTICE 'Cleanup zakończony - rozpoczynam instalację';
END $$;

-- 2. Utworzenie tabeli process_executions
CREATE TABLE public.process_executions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    process_id UUID NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED_ON_TIME', 'COMPLETED_LATE', 'OVERDUE', 'DELAYED_WITH_REASON')),
    completed_at TIMESTAMP WITH TIME ZONE,
    completed_by UUID,
    completion_note TEXT,
    deadline_date DATE,
    deadline_time TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT process_executions_unique UNIQUE (process_id, year, month)
);

-- 3. Dodaj foreign key po utworzeniu tabeli
ALTER TABLE public.process_executions 
ADD CONSTRAINT fk_process_executions_process_id 
FOREIGN KEY (process_id) REFERENCES public.processes(id) ON DELETE CASCADE;

-- 4. Indeksy
CREATE INDEX idx_process_executions_process_id ON public.process_executions(process_id);
CREATE INDEX idx_process_executions_year_month ON public.process_executions(year, month);
CREATE INDEX idx_process_executions_status ON public.process_executions(status);
CREATE INDEX idx_process_executions_completed_by ON public.process_executions(completed_by);
CREATE INDEX idx_process_executions_deadline_date ON public.process_executions(deadline_date);

-- 5. RLS - BARDZO PROSTE
ALTER TABLE public.process_executions ENABLE ROW LEVEL SECURITY;

-- Polityka tylko dla właścicieli projektów (bez project_members)
CREATE POLICY "process_executions_owner_only" ON public.process_executions
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.processes p
            JOIN public.sheets s ON p.sheet_id = s.id
            JOIN public.projects pr ON s.project_id = pr.id
            WHERE p.id = process_executions.process_id
            AND pr.user_id = auth.uid()
        )
    );

-- 6. Trigger dla updated_at
CREATE FUNCTION update_process_executions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_process_executions_updated_at
    BEFORE UPDATE ON public.process_executions
    FOR EACH ROW
    EXECUTE FUNCTION update_process_executions_updated_at();

-- 7. Funkcja do pobierania wykonań dla miesiąca
CREATE FUNCTION get_process_executions_for_month(
    p_sheet_id UUID,
    p_year INTEGER,
    p_month INTEGER
)
RETURNS TABLE (
    process_id UUID,
    process_short_name VARCHAR(255),
    process_description TEXT,
    process_working_day INTEGER,
    process_due_time VARCHAR(10),
    execution_status VARCHAR(50),
    execution_completed_at TIMESTAMP WITH TIME ZONE,
    execution_completed_by UUID,
    execution_completion_note TEXT,
    execution_deadline_date DATE,
    execution_deadline_time TIME
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.short_name,
        p.description,
        p.working_day,
        p.due_time,
        COALESCE(pe.status, 'PENDING'::VARCHAR(50)),
        pe.completed_at,
        pe.completed_by,
        pe.completion_note,
        pe.deadline_date,
        pe.deadline_time
    FROM public.processes p
    LEFT JOIN public.process_executions pe ON (
        pe.process_id = p.id 
        AND pe.year = p_year 
        AND pe.month = p_month
    )
    WHERE p.sheet_id = p_sheet_id
    ORDER BY p.working_day NULLS LAST, p.short_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Funkcja do aktualizacji statusu
CREATE FUNCTION update_process_execution_status(
    p_process_id UUID,
    p_year INTEGER,
    p_month INTEGER,
    p_status VARCHAR(50),
    p_completion_note TEXT DEFAULT NULL,
    p_completed_by UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    execution_id UUID;
    process_due_date DATE;
    process_due_time TIME;
    current_user_id UUID;
BEGIN
    -- Pobierz current user
    SELECT auth.uid() INTO current_user_id;
    
    -- Pobierz informacje o deadline z procesu
    SELECT 
        due_date,
        CASE 
            WHEN due_time IS NOT NULL AND due_time != '' THEN due_time::TIME
            ELSE NULL
        END
    INTO process_due_date, process_due_time
    FROM public.processes
    WHERE id = p_process_id;
    
    -- Wstaw lub zaktualizuj rekord wykonania
    INSERT INTO public.process_executions (
        process_id,
        year,
        month,
        status,
        completed_at,
        completed_by,
        completion_note,
        deadline_date,
        deadline_time
    ) VALUES (
        p_process_id,
        p_year,
        p_month,
        p_status,
        CASE WHEN p_status != 'PENDING' THEN NOW() ELSE NULL END,
        CASE WHEN p_status != 'PENDING' THEN COALESCE(p_completed_by, current_user_id) ELSE NULL END,
        p_completion_note,
        process_due_date,
        process_due_time
    )
    ON CONFLICT (process_id, year, month) 
    DO UPDATE SET
        status = EXCLUDED.status,
        completed_at = CASE WHEN EXCLUDED.status != 'PENDING' THEN NOW() ELSE process_executions.completed_at END,
        completed_by = CASE WHEN EXCLUDED.status != 'PENDING' THEN COALESCE(p_completed_by, current_user_id) ELSE process_executions.completed_by END,
        completion_note = COALESCE(EXCLUDED.completion_note, process_executions.completion_note),
        updated_at = NOW()
    RETURNING id INTO execution_id;
    
    RETURN execution_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Migracja istniejących danych (bezpieczna)
DO $$
DECLARE
    migrated_count INTEGER := 0;
BEGIN
    -- Migruj dane z processes gdzie status != 'PENDING'
    INSERT INTO public.process_executions (
        process_id, 
        year, 
        month, 
        status, 
        completed_at, 
        completed_by,
        completion_note,
        deadline_date,
        created_at,
        updated_at
    )
    SELECT 
        p.id,
        CASE 
            WHEN p.completed_at IS NOT NULL THEN EXTRACT(YEAR FROM p.completed_at)::INTEGER
            ELSE EXTRACT(YEAR FROM NOW())::INTEGER
        END,
        CASE 
            WHEN p.completed_at IS NOT NULL THEN EXTRACT(MONTH FROM p.completed_at)::INTEGER
            ELSE EXTRACT(MONTH FROM NOW())::INTEGER
        END,
        p.status,
        p.completed_at,
        p.assigned_to,
        p.completion_note,
        p.due_date,
        COALESCE(p.created_at, NOW()),
        COALESCE(p.updated_at, NOW())
    FROM public.processes p
    WHERE p.status IS NOT NULL AND p.status != 'PENDING'
    ON CONFLICT (process_id, year, month) DO NOTHING;
    
    GET DIAGNOSTICS migrated_count = ROW_COUNT;
    RAISE NOTICE 'Zmigrowano % rekordów z tabeli processes', migrated_count;
END $$;

-- 10. Komentarze
COMMENT ON TABLE public.process_executions IS 'Historia wykonań procesów per miesiąc';
COMMENT ON COLUMN public.process_executions.process_id IS 'ID procesu';
COMMENT ON COLUMN public.process_executions.year IS 'Rok wykonania';
COMMENT ON COLUMN public.process_executions.month IS 'Miesiąc wykonania (1-12)';
COMMENT ON COLUMN public.process_executions.status IS 'Status wykonania procesu';

-- 11. Test instalacji
DO $$
DECLARE
    table_count INTEGER;
    function_count INTEGER;
BEGIN
    -- Sprawdź czy tabela istnieje
    SELECT COUNT(*) INTO table_count 
    FROM information_schema.tables 
    WHERE table_name = 'process_executions';
    
    -- Sprawdź czy funkcje istnieją
    SELECT COUNT(*) INTO function_count 
    FROM pg_proc 
    WHERE proname IN ('get_process_executions_for_month', 'update_process_execution_status');
    
    IF table_count = 1 AND function_count = 2 THEN
        RAISE NOTICE '✅ SUCCESS: Process Executions system installed successfully!';
        RAISE NOTICE '✅ Tabela: process_executions utworzona';
        RAISE NOTICE '✅ Funkcje: get_process_executions_for_month, update_process_execution_status utworzone';
        RAISE NOTICE '✅ System gotowy do użycia!';
    ELSE
        RAISE NOTICE '❌ Installation incomplete: table_count=%, function_count=%', table_count, function_count;
    END IF;
END $$;

-- Final result
SELECT 
    'Process Executions System' as component,
    'INSTALLED SUCCESSFULLY' as status,
    COUNT(*) as total_executions
FROM public.process_executions;