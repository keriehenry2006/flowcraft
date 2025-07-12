-- =====================================================
-- MINIMAL MIGRATION: Project Invitations Only
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

-- Enable RLS
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_invitations ENABLE ROW LEVEL SECURITY;

-- Project Members Policies
DROP POLICY IF EXISTS "Users can view members of their projects or projects they are members of" ON public.project_members;
CREATE POLICY "Users can view members of their projects or projects they are members of" ON public.project_members
    FOR SELECT USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        ) OR user_id = auth.uid()
    );

DROP POLICY IF EXISTS "Project owners can manage members" ON public.project_members;
CREATE POLICY "Project owners can manage members" ON public.project_members
    FOR ALL USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

-- Project Invitations Policies
DROP POLICY IF EXISTS "Users can view invitations for their projects" ON public.project_invitations;
CREATE POLICY "Users can view invitations for their projects" ON public.project_invitations
    FOR SELECT USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        ) OR email = auth.email()
    );

DROP POLICY IF EXISTS "Project owners can manage invitations" ON public.project_invitations;
CREATE POLICY "Project owners can manage invitations" ON public.project_invitations
    FOR ALL USING (
        project_id IN (
            SELECT id FROM public.projects WHERE user_id = auth.uid()
        )
    );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_project_members_project_id ON public.project_members(project_id);
CREATE INDEX IF NOT EXISTS idx_project_members_user_id ON public.project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_project_invitations_project_id ON public.project_invitations(project_id);
CREATE INDEX IF NOT EXISTS idx_project_invitations_email ON public.project_invitations(email);
CREATE INDEX IF NOT EXISTS idx_project_invitations_token ON public.project_invitations(invitation_token);

-- Grant permissions
GRANT ALL ON public.project_members TO authenticated;
GRANT ALL ON public.project_invitations TO authenticated;