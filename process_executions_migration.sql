-- ==========================================
-- MIGRACJA: Dodanie tabeli process_executions
-- Data: 2025-01-13
-- Opis: Dodanie systemu historii miesięcznej dla procesów
-- ==========================================

-- 1. Utworzenie tabeli process_executions
CREATE TABLE public.process_executions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED_ON_TIME', 'COMPLETED_LATE', 'OVERDUE', 'DELAYED_WITH_REASON')),
    completed_at TIMESTAMP WITH TIME ZONE,
    completed_by UUID REFERENCES auth.users(id),
    completion_note TEXT,
    deadline_date DATE,
    deadline_time TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unikalny constraint - jeden rekord na proces per miesiąc
    CONSTRAINT process_executions_unique UNIQUE (process_id, year, month)
);

-- 2. Indeksy dla wydajności
CREATE INDEX idx_process_executions_process_id ON public.process_executions(process_id);
CREATE INDEX idx_process_executions_year_month ON public.process_executions(year, month);
CREATE INDEX idx_process_executions_status ON public.process_executions(status);
CREATE INDEX idx_process_executions_completed_by ON public.process_executions(completed_by);
CREATE INDEX idx_process_executions_deadline_date ON public.process_executions(deadline_date);

-- 3. Polityki RLS (Row Level Security)
ALTER TABLE public.process_executions ENABLE ROW LEVEL SECURITY;

-- Polityka dla właścicieli projektów i członków z odpowiednimi uprawnieniami
CREATE POLICY "process_executions_access_policy" ON public.process_executions
    USING (
        process_id IN (
            SELECT p.id 
            FROM public.processes p
            JOIN public.sheets s ON p.sheet_id = s.id
            JOIN public.projects pr ON s.project_id = pr.id
            WHERE 
                pr.user_id = auth.uid() 
                OR EXISTS (
                    SELECT 1 FROM public.project_members pm 
                    WHERE pm.project_id = pr.id 
                    AND pm.user_id = auth.uid()
                )
        )
    );

-- 4. Trigger dla aktualizacji updated_at
CREATE OR REPLACE FUNCTION update_process_executions_updated_at()
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

-- 5. Migracja istniejących danych z tabeli processes
-- Dla każdego procesu, który ma status inny niż PENDING, utworzenie rekordu w process_executions
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
SELECT DISTINCT
    p.id as process_id,
    CASE 
        WHEN p.completed_at IS NOT NULL THEN EXTRACT(YEAR FROM p.completed_at)::INTEGER
        ELSE EXTRACT(YEAR FROM NOW())::INTEGER
    END as year,
    CASE 
        WHEN p.completed_at IS NOT NULL THEN EXTRACT(MONTH FROM p.completed_at)::INTEGER
        ELSE EXTRACT(MONTH FROM NOW())::INTEGER
    END as month,
    p.status,
    p.completed_at,
    p.assigned_to as completed_by,
    p.completion_note,
    p.due_date as deadline_date,
    p.created_at,
    p.updated_at
FROM public.processes p
WHERE p.status != 'PENDING'
ON CONFLICT (process_id, year, month) DO NOTHING;

-- 6. Funkcja pomocnicza do pobierania wykonań procesów dla miesiąca
CREATE OR REPLACE FUNCTION get_process_executions_for_month(
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
        p.id as process_id,
        p.short_name as process_short_name,
        p.description as process_description,
        p.working_day as process_working_day,
        p.due_time as process_due_time,
        COALESCE(pe.status, 'PENDING') as execution_status,
        pe.completed_at as execution_completed_at,
        pe.completed_by as execution_completed_by,
        pe.completion_note as execution_completion_note,
        pe.deadline_date as execution_deadline_date,
        pe.deadline_time as execution_deadline_time
    FROM public.processes p
    LEFT JOIN public.process_executions pe ON (
        pe.process_id = p.id 
        AND pe.year = p_year 
        AND pe.month = p_month
    )
    WHERE p.sheet_id = p_sheet_id
    ORDER BY p.working_day, p.short_name;
END;
$$ LANGUAGE plpgsql;

-- 7. Funkcja do aktualizacji statusu wykonania procesu
CREATE OR REPLACE FUNCTION update_process_execution_status(
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
BEGIN
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
        CASE WHEN p_status != 'PENDING' THEN COALESCE(p_completed_by, auth.uid()) ELSE NULL END,
        p_completion_note,
        process_due_date,
        process_due_time
    )
    ON CONFLICT (process_id, year, month) 
    DO UPDATE SET
        status = EXCLUDED.status,
        completed_at = CASE WHEN EXCLUDED.status != 'PENDING' THEN NOW() ELSE process_executions.completed_at END,
        completed_by = CASE WHEN EXCLUDED.status != 'PENDING' THEN COALESCE(p_completed_by, auth.uid()) ELSE process_executions.completed_by END,
        completion_note = COALESCE(EXCLUDED.completion_note, process_executions.completion_note),
        updated_at = NOW()
    RETURNING id INTO execution_id;
    
    RETURN execution_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Dodanie komentarzy do tabeli
COMMENT ON TABLE public.process_executions IS 'Tabela przechowująca historię wykonań procesów per miesiąc';
COMMENT ON COLUMN public.process_executions.process_id IS 'Odniesienie do procesu';
COMMENT ON COLUMN public.process_executions.year IS 'Rok wykonania';
COMMENT ON COLUMN public.process_executions.month IS 'Miesiąc wykonania (1-12)';
COMMENT ON COLUMN public.process_executions.status IS 'Status wykonania procesu w danym miesiącu';
COMMENT ON COLUMN public.process_executions.deadline_date IS 'Skopiowana data deadline z procesu';
COMMENT ON COLUMN public.process_executions.deadline_time IS 'Skopiowana godzina deadline z procesu';

-- Koniec migracji