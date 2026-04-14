"""
PHI Chief AI - AskPhi OAuth Server
Secure server-side authorization code flow with PKCE
"""

from flask import Flask, request, jsonify, redirect, session, render_template_string
from flask_cors import CORS
import secrets
import hashlib
import base64
import requests
import os
from datetime import datetime, timedelta
import jwt

app = Flask(__name__)
CORS(app)

# Secure session configuration
app.secret_key = secrets.token_hex(32)

# OAuth Configuration
GITHUB_CLIENT_ID = os.getenv('GITHUB_CLIENT_ID', 'your_client_id_here')
GITHUB_CLIENT_SECRET = os.getenv('GITHUB_CLIENT_SECRET', 'your_client_secret_here')
JWT_SECRET = secrets.token_hex(32)

# PKCE Helper Functions
def generate_code_verifier():
    """Generate a cryptographically secure code verifier"""
    return secrets.token_urlsafe(32)

def generate_code_challenge(verifier):
    """Generate code challenge from verifier using S256"""
    sha256 = hashlib.sha256(verifier.encode('utf-8')).digest()
    return base64.urlsafe_b64encode(sha256).decode('utf-8').rstrip('=')

def verify_state(expected_state, received_state):
    """Verify OAuth state parameter to prevent CSRF"""
    return secrets.compare_digest(expected_state, received_state)

# Routes
@app.route('/')
def index():
    """Serve the AskPhi widget"""
    return render_template_string('''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>PHI Chief AI - AskPhi</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #000000 0%, #797979 100%);
                margin: 0;
                padding: 20px;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .widget-container {
                background: white;
                border-radius: 12px;
                padding: 30px;
                box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                max-width: 500px;
                width: 100%;
            }
            .header {
                text-align: center;
                margin-bottom: 30px;
            }
            .phi-logo {
                font-size: 2.5em;
                color: #000000;
                margin-bottom: 10px;
            }
            .subtitle {
                color: #666;
                font-size: 1.1em;
            }
            .auth-section {
                text-align: center;
            }
            .github-btn {
                background: #24292e;
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 6px;
                font-size: 16px;
                cursor: pointer;
                text-decoration: none;
                display: inline-block;
                margin: 10px 0;
                transition: background 0.3s;
            }
            .github-btn:hover {
                background: #1a1e22;
            }
            .status {
                margin-top: 20px;
                padding: 10px;
                border-radius: 6px;
                font-size: 14px;
            }
            .status.success {
                background: #d4edda;
                color: #155724;
                border: 1px solid #c3e6cb;
            }
            .status.error {
                background: #f8d7da;
                color: #721c24;
                border: 1px solid #f5c6cb;
            }
        </style>
    </head>
    <body>
        <div class="widget-container">
            <div class="header">
                <div class="phi-logo">Φ</div>
                <h1>PHI Chief AI</h1>
                <p class="subtitle">AskPhi - Sovereign AI Assistant</p>
            </div>

            <div class="auth-section">
                <p>Connect with GitHub to access PHI Chief AI capabilities:</p>
                <a href="/auth/github" class="github-btn">
                    🔐 Authenticate with GitHub
                </a>

                <div id="status" class="status" style="display: none;"></div>
            </div>
        </div>

        <script>
            // Check for authentication status
            const urlParams = new URLSearchParams(window.location.search);
            const token = urlParams.get('token');
            const error = urlParams.get('error');

            if (token) {
                localStorage.setItem('phi_token', token);
                showStatus('Authentication successful! Redirecting...', 'success');
                setTimeout(() => {
                    window.location.href = '/chat';
                }, 2000);
            } else if (error) {
                showStatus('Authentication failed: ' + error, 'error');
            }

            function showStatus(message, type) {
                const statusDiv = document.getElementById('status');
                statusDiv.textContent = message;
                statusDiv.className = 'status ' + type;
                statusDiv.style.display = 'block';
            }
        </script>
    </body>
    </html>
    ''')

@app.route('/auth/github')
def github_auth():
    """Initiate GitHub OAuth flow with PKCE"""
    # Generate PKCE values
    code_verifier = generate_code_verifier()
    code_challenge = generate_code_challenge(code_verifier)

    # Generate state for CSRF protection
    state = secrets.token_urlsafe(32)

    # Store values in session
    session['code_verifier'] = code_verifier
    session['state'] = state

    # GitHub OAuth URL
    github_url = (
        "https://github.com/login/oauth/authorize?"
        f"client_id={GITHUB_CLIENT_ID}&"
        "response_type=code&"
        f"redirect_uri={request.host_url}auth/callback&"
        f"scope=read:user&"
        f"state={state}&"
        f"code_challenge={code_challenge}&"
        "code_challenge_method=S256"
    )

    return redirect(github_url)

@app.route('/auth/callback')
def github_callback():
    """Handle GitHub OAuth callback"""
    code = request.args.get('code')
    state = request.args.get('state')
    error = request.args.get('error')

    # Check for errors
    if error:
        return redirect(f"/?error={error}")

    # Verify state
    expected_state = session.get('state')
    if not verify_state(expected_state, state):
        return redirect("/?error=invalid_state")

    # Get code verifier from session
    code_verifier = session.get('code_verifier')
    if not code_verifier:
        return redirect("/?error=missing_code_verifier")

    try:
        # Exchange code for access token
        token_response = requests.post(
            'https://github.com/login/oauth/access_token',
            headers={
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            data={
                'client_id': GITHUB_CLIENT_ID,
                'client_secret': GITHUB_CLIENT_SECRET,
                'code': code,
                'redirect_uri': f"{request.host_url}auth/callback",
                'code_verifier': code_verifier
            }
        )

        token_data = token_response.json()

        if 'access_token' not in token_data:
            return redirect(f"/?error={token_data.get('error', 'token_exchange_failed')}")

        access_token = token_data['access_token']

        # Get user info
        user_response = requests.get(
            'https://api.github.com/user',
            headers={'Authorization': f'token {access_token}'}
        )

        if user_response.status_code != 200:
            return redirect("/?error=user_info_failed")

        user_data = user_response.json()

        # Check if user is authorized (Fractal5 Solutions organization)
        org_response = requests.get(
            'https://api.github.com/user/orgs',
            headers={'Authorization': f'token {access_token}'}
        )

        authorized_orgs = ['Fractal5-Solutions']
        user_orgs = [org['login'] for org in org_response.json()] if org_response.status_code == 200 else []

        if not any(org in authorized_orgs for org in user_orgs):
            return redirect("/?error=unauthorized_organization")

        # Generate JWT token for PHI Chief AI
        jwt_payload = {
            'user_id': user_data['id'],
            'username': user_data['login'],
            'orgs': user_orgs,
            'exp': datetime.utcnow() + timedelta(hours=24)
        }

        jwt_token = jwt.encode(jwt_payload, JWT_SECRET, algorithm='HS256')

        # Redirect to widget with token
        return redirect(f"/?token={jwt_token}")

    except Exception as e:
        return redirect(f"/?error=server_error")

@app.route('/chat')
def chat():
    """PHI Chief AI Chat Interface"""
    token = request.args.get('token') or request.headers.get('Authorization', '').replace('Bearer ', '')

    if not token:
        return redirect('/')

    try:
        # Verify JWT token
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        username = payload['username']
    except jwt.ExpiredSignatureError:
        return redirect('/?error=token_expired')
    except jwt.InvalidTokenError:
        return redirect('/?error=invalid_token')

    return render_template_string(f'''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>PHI Chief AI - Chat</title>
        <style>
            body {{
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #000000 0%, #797979 100%);
                margin: 0;
                padding: 20px;
                min-height: 100vh;
            }}
            .chat-container {{
                background: white;
                border-radius: 12px;
                padding: 30px;
                box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                max-width: 800px;
                width: 100%;
                margin: 0 auto;
                height: calc(100vh - 40px);
                display: flex;
                flex-direction: column;
            }}
            .header {{
                text-align: center;
                margin-bottom: 20px;
                border-bottom: 1px solid #eee;
                padding-bottom: 20px;
            }}
            .user-info {{
                color: #666;
                font-size: 14px;
            }}
            .chat-messages {{
                flex: 1;
                overflow-y: auto;
                padding: 20px 0;
                border-bottom: 1px solid #eee;
            }}
            .message {{
                margin-bottom: 20px;
                padding: 15px;
                border-radius: 8px;
                max-width: 70%;
            }}
            .message.user {{
                background: #000000;
                color: white;
                margin-left: auto;
                text-align: right;
            }}
            .message.phi {{
                background: #f8f9fa;
                color: #333;
            }}
            .chat-input {{
                display: flex;
                gap: 10px;
                padding-top: 20px;
            }}
            .chat-input input {{
                flex: 1;
                padding: 12px;
                border: 1px solid #ddd;
                border-radius: 6px;
                font-size: 16px;
            }}
            .chat-input button {{
                padding: 12px 24px;
                background: #000000;
                color: white;
                border: none;
                border-radius: 6px;
                cursor: pointer;
                font-size: 16px;
            }}
            .chat-input button:hover {{
                background: #5a67d8;
            }}
        </style>
    </head>
    <body>
        <div class="chat-container">
            <div class="header">
                <h1>Φ PHI Chief AI</h1>
                <div class="user-info">Authenticated as: {username}</div>
            </div>

            <div class="chat-messages" id="messages">
                <div class="message phi">
                    <strong>PHI Chief AI:</strong> Welcome to PHI Chief AI, {username}! I am your sovereign AI assistant. How can I help you today?
                </div>
            </div>

            <div class="chat-input">
                <input type="text" id="messageInput" placeholder="Ask me anything..." onkeypress="handleKeyPress(event)">
                <button onclick="sendMessage()">Send</button>
            </div>
        </div>

        <script>
            const token = '{token}';
            const messagesDiv = document.getElementById('messages');
            const messageInput = document.getElementById('messageInput');

            function handleKeyPress(event) {{
                if (event.key === 'Enter') {{
                    sendMessage();
                }}
            }}

            async function sendMessage() {{
                const message = messageInput.value.trim();
                if (!message) return;

                // Add user message
                addMessage(message, 'user');
                messageInput.value = '';

                // Send to PHI Chief AI
                try {{
                    const response = await fetch('/api/chat', {{
                        method: 'POST',
                        headers: {{
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${{token}}`
                        }},
                        body: JSON.stringify({{ message: message }})
                    }});

                    const data = await response.json();
                    addMessage(data.response, 'phi');
                }} catch (error) {{
                    addMessage('Sorry, I encountered an error. Please try again.', 'phi');
                }}
            }}

            function addMessage(text, sender) {{
                const messageDiv = document.createElement('div');
                messageDiv.className = `message ${{sender}}`;
                messageDiv.innerHTML = `<strong>${{sender === 'user' ? 'You' : 'PHI Chief AI'}}:</strong> ${{text}}`;
                messagesDiv.appendChild(messageDiv);
                messagesDiv.scrollTop = messagesDiv.scrollHeight;
            }}
        </script>
    </body>
    </html>
    ''')

@app.route('/api/chat', methods=['POST'])
def chat_api():
    """PHI Chief AI Chat API"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    data = request.get_json()

    if not token or not data:
        return jsonify({'error': 'Invalid request'}), 400

    try:
        # Verify JWT token
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        message = data.get('message', '')

        # PHI Chief AI Response Logic
        response = generate_phi_response(message, payload)

        return jsonify({'response': response})

    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'Token expired'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': 'Invalid token'}), 401
    except Exception as e:
        return jsonify({'error': 'Server error'}), 500

def generate_phi_response(message, user_payload):
    """Generate PHI Chief AI response based on user context"""
    username = user_payload.get('username', 'user')
    orgs = user_payload.get('orgs', [])

    # Basic response logic - in production, this would integrate with PHI Chief AI
    responses = {
        'hello': f"Hello {username}! I am PHI Chief AI, your sovereign autonomous assistant. How can I help you with your AI operations today?",
        'help': "I can help you with:\n• System monitoring and optimization\n• Relationship intelligence deployment\n• Security analysis and remediation\n• Autonomous operations management\n• Sovereign AI governance\n\nWhat would you like to know?",
        'status': f"System Status: All PHI Chief AI systems are operational. User {username} authenticated from {', '.join(orgs) if orgs else 'authorized organization'}.",
        'security': "Security protocols active:\n• OAuth 2.0 with PKCE implemented\n• JWT token authentication\n• Organization-based authorization\n• AI-powered threat detection\n• Comprehensive audit logging",
        'sovereign': "PHI Chief AI maintains complete sovereignty:\n• Autonomous decision making\n• NHITL (Not Human In The Loop) operations\n• Multi-cloud deployment resilience\n• Zero-trust security model\n• Sovereign data governance"
    }

    message_lower = message.lower()

    for key, response in responses.items():
        if key in message_lower:
            return response

    # Default response
    return f"I understand you're asking about: '{message}'. As PHI Chief AI, I'm here to help with your autonomous AI operations. Could you provide more details about what you need assistance with?"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False, ssl_context='adhoc')
