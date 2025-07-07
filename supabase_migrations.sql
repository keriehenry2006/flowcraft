-- =====================================================
-- Process Flow Manager Database Schema
-- =====================================================

-- Note: auth.users table is managed by Supabase Auth and already has RLS enabled

-- =====================================================
-- 1. PROJECTS TABLE
-- =====================================================
CREATE TABLE public.projects (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT projects_name_user_unique UNIQUE (name, user_id)
);

-- Enable RLS for projects
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

-- RLS Policies for projects
CREATE POLICY "Users can view their own projects" ON public.projects
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own projects" ON public.projects
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own projects" ON public.projects
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own projects" ON public.projects
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- 2. SHEETS TABLE
-- =====================================================
CREATE TABLE public.sheets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    custom_fields JSONB DEFAULT '{}', -- Stores custom field definitions
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT sheets_name_project_unique UNIQUE (name, project_id)
);

-- Enable RLS for sheets
ALTER TABLE public.sheets ENABLE ROW LEVEL SECURITY;

-- RLS Policies for sheets
CREATE POLICY "Users can view sheets in their projects" ON public.sheets
    FOR SELECT USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert sheets in their projects" ON public.sheets
    FOR INSERT WITH CHECK (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update sheets in their projects" ON public.sheets
    FOR UPDATE USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete sheets in their projects" ON public.sheets
    FOR DELETE USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

-- =====================================================
-- 3. PROCESSES TABLE (Updated)
-- =====================================================
-- Drop dependent views first, then table, then recreate
DROP VIEW IF EXISTS process_full CASCADE;
DROP VIEW IF EXISTS processes_with_dep_info CASCADE; 
DROP TABLE IF EXISTS public.processes CASCADE;

CREATE TABLE public.processes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Required fields for diagram functionality
    short_name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    working_day INTEGER DEFAULT 0,
    due_time VARCHAR(10), -- HH:MM:SS format
    dependencies TEXT DEFAULT '',
    process_type VARCHAR(50) DEFAULT 'standard',
    
    -- System fields
    sheet_id UUID REFERENCES public.sheets(id) ON DELETE CASCADE,
    custom_data JSONB DEFAULT '{}', -- Stores custom field values
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT processes_short_name_sheet_unique UNIQUE (short_name, sheet_id)
);

-- Enable RLS for processes
ALTER TABLE public.processes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for processes
CREATE POLICY "Users can view processes in their sheets" ON public.processes
    FOR SELECT USING (
        sheet_id IN (
            SELECT s.id FROM public.sheets s
            JOIN public.projects p ON s.project_id = p.id
            WHERE p.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert processes in their sheets" ON public.processes
    FOR INSERT WITH CHECK (
        sheet_id IN (
            SELECT s.id FROM public.sheets s
            JOIN public.projects p ON s.project_id = p.id
            WHERE p.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update processes in their sheets" ON public.processes
    FOR UPDATE USING (
        sheet_id IN (
            SELECT s.id FROM public.sheets s
            JOIN public.projects p ON s.project_id = p.id
            WHERE p.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete processes in their sheets" ON public.processes
    FOR DELETE USING (
        sheet_id IN (
            SELECT s.id FROM public.sheets s
            JOIN public.projects p ON s.project_id = p.id
            WHERE p.user_id = auth.uid()
        )
    );

-- =====================================================
-- 4. INDEXES for Performance
-- =====================================================
CREATE INDEX idx_projects_user_id ON public.projects(user_id);
CREATE INDEX idx_projects_created_at ON public.projects(created_at);

CREATE INDEX idx_sheets_project_id ON public.sheets(project_id);
CREATE INDEX idx_sheets_created_at ON public.sheets(created_at);

CREATE INDEX idx_processes_sheet_id ON public.processes(sheet_id);
CREATE INDEX idx_processes_short_name ON public.processes(short_name);
CREATE INDEX idx_processes_working_day ON public.processes(working_day);

-- =====================================================
-- 5. FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for auto-updating updated_at
CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sheets_updated_at BEFORE UPDATE ON public.sheets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_processes_updated_at BEFORE UPDATE ON public.processes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. VIEWS for Easy Data Access
-- =====================================================

-- View for projects with sheet count
CREATE OR REPLACE VIEW project_summary AS
SELECT 
    p.*,
    COUNT(s.id) as sheet_count
FROM public.projects p
LEFT JOIN public.sheets s ON p.id = s.project_id
GROUP BY p.id, p.name, p.description, p.user_id, p.created_at, p.updated_at;

-- View for sheets with process count
CREATE OR REPLACE VIEW sheet_summary AS
SELECT 
    s.*,
    COUNT(pr.id) as process_count
FROM public.sheets s
LEFT JOIN public.processes pr ON s.id = pr.sheet_id
GROUP BY s.id, s.name, s.description, s.project_id, s.custom_fields, s.created_at, s.updated_at;

-- View for full process data with sheet and project info
CREATE OR REPLACE VIEW process_full AS
SELECT 
    pr.*,
    s.name as sheet_name,
    s.custom_fields as sheet_custom_fields,
    p.name as project_name,
    p.user_id as owner_id
FROM public.processes pr
JOIN public.sheets s ON pr.sheet_id = s.id
JOIN public.projects p ON s.project_id = p.id;

-- =====================================================
-- 7. SAMPLE DATA (Optional - for testing)
-- =====================================================

-- Insert sample project (uncomment for testing)
/*
INSERT INTO public.projects (name, description, user_id) VALUES 
('Sample Manufacturing Process', 'Production line workflow management', auth.uid());

-- Insert sample sheet (uncomment for testing)
INSERT INTO public.sheets (name, description, project_id, custom_fields) VALUES 
('Daily Operations', 'Daily manufacturing operations', 
 (SELECT id FROM public.projects WHERE name = 'Sample Manufacturing Process' LIMIT 1),
 '{"Priority": "select", "Owner": "text", "Status": "select"}');

-- Insert sample processes (uncomment for testing)
INSERT INTO public.processes (short_name, description, working_day, due_time, process_type, sheet_id, custom_data) VALUES 
('START', 'Production start checkpoint', 0, '08:00:00', 'standard', 
 (SELECT id FROM public.sheets WHERE name = 'Daily Operations' LIMIT 1),
 '{"Priority": "High", "Owner": "Team Lead", "Status": "Active"}'),
('SETUP', 'Machine setup and calibration', 0, '08:30:00', 'blocking',
 (SELECT id FROM public.sheets WHERE name = 'Daily Operations' LIMIT 1),
 '{"Priority": "High", "Owner": "Technician", "Status": "Active"}');
*/

-- =====================================================
-- 8. GRANT PERMISSIONS
-- =====================================================

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.projects TO authenticated;
GRANT ALL ON public.sheets TO authenticated;
GRANT ALL ON public.processes TO authenticated;
GRANT SELECT ON project_summary TO authenticated;
GRANT SELECT ON sheet_summary TO authenticated;
GRANT SELECT ON process_full TO authenticated;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- To apply this migration:
-- 1. Copy and paste this SQL into Supabase SQL Editor
-- 2. Run the script
-- 3. Verify tables are created with proper RLS policies
-- 4. Test with sample data if needed 