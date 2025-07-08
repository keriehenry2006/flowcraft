-- =====================================================
-- MISSING TABLES MIGRATION - Apply this in Supabase SQL Editor
-- =====================================================

-- Project Members Table
CREATE TABLE IF NOT EXISTS public.project_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('FULL_ACCESS', 'EDIT_ACCESS', 'VIEW_ONLY')),
    invited_by UUID REFERENCES auth.users(id),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT project_members_unique UNIQUE (project_id, user_id)
);

-- Project Invitations Table
CREATE TABLE IF NOT EXISTS public.project_invitations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('FULL_ACCESS', 'EDIT_ACCESS', 'VIEW_ONLY')),
    invitation_token VARCHAR(255) NOT NULL UNIQUE,
    invited_by UUID REFERENCES auth.users(id),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'EXPIRED', 'REVOKED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT project_invitations_unique UNIQUE (project_id, email)
);

-- Working Calendar Table
CREATE TABLE IF NOT EXISTS public.working_calendar (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    working_days_json JSONB NOT NULL,
    holidays_json JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT working_calendar_unique UNIQUE (year, month)
);

-- Process Status History Table
CREATE TABLE IF NOT EXISTS public.process_status_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    process_id UUID REFERENCES public.processes(id) ON DELETE CASCADE,
    old_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    changed_by UUID REFERENCES auth.users(id),
    change_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add new columns to processes table
ALTER TABLE public.processes 
ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED_ON_TIME', 'COMPLETED_LATE', 'OVERDUE', 'DELAYED_WITH_REASON')),
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS completion_note TEXT,
ADD COLUMN IF NOT EXISTS due_date DATE,
ADD COLUMN IF NOT EXISTS actual_due_datetime TIMESTAMP WITH TIME ZONE;

-- Enable RLS
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.working_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.process_status_history ENABLE ROW LEVEL SECURITY;

-- Project Members Policies
CREATE POLICY "Users can view members of their projects or projects they are members of" ON public.project_members
    FOR SELECT USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        ) OR user_id = auth.uid()
    );

CREATE POLICY "Project owners can manage members" ON public.project_members
    FOR ALL USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

-- Project Invitations Policies
CREATE POLICY "Users can view invitations for their projects" ON public.project_invitations
    FOR SELECT USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        ) OR email = auth.email()
    );

CREATE POLICY "Project owners can manage invitations" ON public.project_invitations
    FOR ALL USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

-- Working Calendar Policies
CREATE POLICY "Authenticated users can view working calendar" ON public.working_calendar
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can manage working calendar" ON public.working_calendar
    FOR ALL TO authenticated USING (true);

-- Process Status History Policies
CREATE POLICY "Users can view status history for their processes" ON public.process_status_history
    FOR SELECT USING (
        process_id IN (
            SELECT pr.id FROM public.processes pr
            JOIN public.sheets s ON pr.sheet_id = s.id
            JOIN public.projects p ON s.project_id = p.id
            WHERE p.user_id = auth.uid() OR p.id IN (
                SELECT pm.project_id FROM public.project_members pm 
                WHERE pm.user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can insert status history for their processes" ON public.process_status_history
    FOR INSERT WITH CHECK (
        process_id IN (
            SELECT pr.id FROM public.processes pr
            JOIN public.sheets s ON pr.sheet_id = s.id
            JOIN public.projects p ON s.project_id = p.id
            WHERE p.user_id = auth.uid() OR p.id IN (
                SELECT pm.project_id FROM public.project_members pm 
                WHERE pm.user_id = auth.uid() AND pm.role IN ('FULL_ACCESS', 'EDIT_ACCESS')
            )
        )
    );

-- Grant permissions
GRANT ALL ON public.project_members TO authenticated;
GRANT ALL ON public.project_invitations TO authenticated;
GRANT ALL ON public.working_calendar TO authenticated;
GRANT ALL ON public.process_status_history TO authenticated;