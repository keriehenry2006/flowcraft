import "jsr:@supabase/functions-js/edge-runtime.d.ts";

interface EmailRequest {
  to: string;
  projectName: string;
  role: string;
  invitationToken: string;
  inviterEmail: string;
  customMessage?: string;
  siteUrl: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      }
    });
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const { to, projectName, role, invitationToken, inviterEmail, customMessage, siteUrl }: EmailRequest = await req.json();

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY environment variable is required');
    }

    const invitationUrl = `${siteUrl}/confirm.html?invitation=${invitationToken}`;
    const roleText = role.replace('_', ' ').toLowerCase();

    const emailHtml = generateInvitationEmailHtml(
      projectName,
      roleText,
      invitationUrl,
      inviterEmail,
      customMessage || '',
      siteUrl
    );

    const emailPayload = {
      from: 'FlowCraft <noreply@flowcraft.bronskipatryk.pl>',
      to: [to],
      subject: `Invitation to collaborate on "${projectName}" project`,
      html: emailHtml
    };

    console.log('Sending email to:', to);
    console.log('Project:', projectName);
    console.log('Role:', roleText);

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(emailPayload)
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(`Email sending failed: ${errorData.message || response.statusText}`);
    }

    const result = await response.json();
    console.log('Email sent successfully:', result);

    return new Response(JSON.stringify({
      success: true,
      messageId: result.id,
      message: 'Invitation email sent successfully'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('Email sending error:', error);
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
});

function generateInvitationEmailHtml(
  projectName: string,
  roleText: string,
  invitationUrl: string,
  inviterEmail: string,
  customMessage: string,
  siteUrl: string
): string {
  // Ensure production URL is used in emails
  const productionSiteUrl = siteUrl.includes('localhost') 
    ? 'https://flowcraft.bronskipatryk.pl' 
    : siteUrl;
  const productionInvitationUrl = invitationUrl.includes('localhost')
    ? invitationUrl.replace(/http:\/\/localhost:\d+/, 'https://flowcraft.bronskipatryk.pl')
    : invitationUrl;
  
  return `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Project Invitation - FlowCraft</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f8fafc;
            }
            .container {
                background: white;
                border-radius: 12px;
                padding: 40px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
            }
            .header {
                text-align: center;
                margin-bottom: 30px;
                border-bottom: 2px solid #e5e7eb;
                padding-bottom: 20px;
            }
            .title {
                color: #1f2937;
                font-size: 28px;
                font-weight: 700;
                margin: 0;
            }
            .subtitle {
                color: #6b7280;
                font-size: 16px;
                margin: 5px 0 0 0;
            }
            .invitation-box {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 25px;
                border-radius: 10px;
                margin: 20px 0;
                text-align: center;
            }
            .project-name {
                font-size: 22px;
                font-weight: 600;
                margin-bottom: 8px;
            }
            .role-info {
                font-size: 16px;
                opacity: 0.9;
                margin-bottom: 20px;
            }
            .accept-button {
                display: inline-block;
                background: white;
                color: #667eea;
                padding: 12px 30px;
                text-decoration: none;
                border-radius: 8px;
                font-weight: 600;
                font-size: 16px;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            }
            .custom-message {
                background: #f3f4f6;
                border-left: 4px solid #667eea;
                padding: 15px 20px;
                margin: 20px 0;
                border-radius: 0 8px 8px 0;
                font-style: italic;
            }
            .registration-info {
                background: #eff6ff;
                border: 1px solid #bfdbfe;
                border-radius: 8px;
                padding: 20px;
                margin: 20px 0;
                text-align: center;
            }
            .footer {
                text-align: center;
                font-size: 14px;
                color: #6b7280;
                margin-top: 40px;
                padding-top: 20px;
                border-top: 1px solid #e5e7eb;
            }
            .direct-link {
                background: #f9fafb;
                border: 1px solid #d1d5db;
                border-radius: 8px;
                padding: 15px;
                margin: 20px 0;
                font-size: 14px;
                color: #4b5563;
            }
            .direct-link code {
                background: #e5e7eb;
                padding: 2px 6px;
                border-radius: 4px;
                font-family: 'Monaco', 'Menlo', monospace;
                word-break: break-all;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1 class="title">Project Invitation</h1>
                <p class="subtitle">You've been invited to collaborate</p>
            </div>
            
            <div class="content">
                <p>Hello!</p>
                <p><strong>${inviterEmail}</strong> has invited you to collaborate on a project in <strong>FlowCraft</strong>.</p>
                
                <div class="invitation-box">
                    <div class="project-name">${projectName}</div>
                    <div class="role-info">Role: ${roleText}</div>
                    <a href="${productionInvitationUrl}" class="accept-button">Accept Invitation</a>
                </div>
                
                ${customMessage ? `
                <div class="custom-message">
                    <strong>Personal message from ${inviterEmail}:</strong><br>
                    ${customMessage}
                </div>
                ` : ''}
                
                <div class="registration-info">
                    <div style="font-weight: 600; color: #1e40af; margin-bottom: 10px;">Don't have an account?</div>
                    <p>No problem! You can create a free FlowCraft account when you accept this invitation.</p>
                    <p>Or register directly at: <a href="${productionSiteUrl}/reset.html" style="color: #2563eb; text-decoration: none; font-weight: 600;">Create Account</a></p>
                </div>
                
                <div class="direct-link">
                    <strong>Can't click the button?</strong> Copy and paste this link into your browser:<br>
                    <code>${productionInvitationUrl}</code>
                </div>
            </div>
            
            <div class="footer">
                <p>This invitation was sent by <strong>${inviterEmail}</strong> via FlowCraft</p>
                <p>If you weren't expecting this invitation, you can safely ignore this email.</p>
                <p>&copy; 2025 FlowCraft. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
  `;
}