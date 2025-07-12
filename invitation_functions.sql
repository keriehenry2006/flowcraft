-- FlowCraft Invitation Management Functions
-- Apply this SQL in Supabase Dashboard > SQL Editor

-- Function to safely revoke invitation
CREATE OR REPLACE FUNCTION revoke_invitation(invitation_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    project_owner UUID;
    invitation_project UUID;
BEGIN
    -- Get the project_id for this invitation
    SELECT project_id INTO invitation_project
    FROM public.project_invitations 
    WHERE id = invitation_id;
    
    IF invitation_project IS NULL THEN
        RETURN FALSE; -- Invitation not found
    END IF;
    
    -- Check if current user is the project owner
    SELECT user_id INTO project_owner
    FROM public.projects 
    WHERE id = invitation_project;
    
    IF project_owner != auth.uid() THEN
        RETURN FALSE; -- Not authorized
    END IF;
    
    -- Update invitation status to REVOKED
    UPDATE public.project_invitations 
    SET status = 'REVOKED'
    WHERE id = invitation_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to safely send invitation (create invitation record)
CREATE OR REPLACE FUNCTION send_invitation(
    project_id_param UUID,
    email_param VARCHAR(255),
    role_param VARCHAR(20),
    invitation_token_param VARCHAR(255),
    expires_at_param TIMESTAMP WITH TIME ZONE
)
RETURNS UUID AS $$
DECLARE
    project_owner UUID;
    new_invitation_id UUID;
BEGIN
    -- Check if current user is the project owner
    SELECT user_id INTO project_owner
    FROM public.projects 
    WHERE id = project_id_param;
    
    IF project_owner != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to send invitations for this project';
    END IF;
    
    -- Check if invitation already exists for this email and project
    SELECT id INTO new_invitation_id
    FROM public.project_invitations
    WHERE project_id = project_id_param AND email = email_param;
    
    IF new_invitation_id IS NOT NULL THEN
        -- Update existing invitation
        UPDATE public.project_invitations 
        SET 
            role = role_param,
            invitation_token = invitation_token_param,
            expires_at = expires_at_param,
            status = 'PENDING',
            created_at = NOW()
        WHERE id = new_invitation_id;
        
        RETURN new_invitation_id;
    ELSE
        -- Create new invitation
        INSERT INTO public.project_invitations (
            project_id, 
            email, 
            role, 
            invitation_token, 
            invited_by, 
            expires_at, 
            status
        ) VALUES (
            project_id_param,
            email_param,
            role_param,
            invitation_token_param,
            auth.uid(),
            expires_at_param,
            'PENDING'
        ) RETURNING id INTO new_invitation_id;
        
        RETURN new_invitation_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION revoke_invitation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION send_invitation(UUID, VARCHAR(255), VARCHAR(20), VARCHAR(255), TIMESTAMP WITH TIME ZONE) TO authenticated;