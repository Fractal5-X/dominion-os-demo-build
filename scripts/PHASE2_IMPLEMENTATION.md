# PHI Chief AI - Phase 2 Implementation: AskPhi Widget

## Overview

Phase 2 implements the AskPhi widget with secure OAuth 2.0 authentication, artifact-only deployment model, and comprehensive security measures.

## Security Architecture

### OAuth 2.0 with PKCE
- Authorization Code Flow with Proof Key for Code Exchange (PKCE)
- CSRF protection via state parameter
- Secure token exchange
- JWT-based session management

### Organization-Based Authorization
- GitHub organization membership verification
- Authorized organizations: Fractal5-Solutions
- Granular permission scoping

### Artifact-Only Deployment
- No operational scripts in deployment artifacts
- Minified, production-ready HTML/JS/CSS only
- Integrity verification with SHA256 checksums
- Automated deployment scripts (not included in artifacts)

## Implementation Components

### 1. OAuth Server (`oauth_server/`)
- Flask-based OAuth 2.0 server
- PKCE implementation
- JWT token generation
- Organization verification
- PHI Chief AI chat API

### 2. AskPhi Widget (`dist/askphi/`)
- Minified HTML widget
- OAuth-initiated authentication
- JWT token handling
- Real-time chat interface

### 3. Deployment Pipeline
- Artifact-only deployment
- Integrity verification
- Automated deployment scripts
- Environment-specific configuration

## Setup Instructions

### OAuth Server Setup

1. **Create GitHub OAuth App:**
   ```bash
   # Go to: https://github.com/settings/applications/new
   # Configure as documented in oauth_server/README.md
   ```

2. **Deploy OAuth Server:**
   ```bash
   cd oauth_server
   pip install -r requirements.txt
   cp .env.example .env
   # Edit .env with OAuth credentials
   python app.py
   ```

### Widget Deployment

1. **Configure Environment:**
   ```bash
   export OAUTH_SERVER_URL="https://phi-oauth.fractal5.solutions"
   export WIDGET_URL="https://askphi.fractal5.solutions"
   ```

2. **Deploy Artifacts:**
   ```bash
   cd dist/askphi
   ./deploy.sh --deploy /var/www/html/askphi
   ```

## Security Features

### Authentication & Authorization
- ✅ OAuth 2.0 Authorization Code Flow
- ✅ PKCE (Proof Key for Code Exchange)
- ✅ JWT Token Authentication
- ✅ Organization-Based Access Control
- ✅ CSRF Protection
- ✅ Secure Session Management

### Deployment Security
- ✅ Artifact-Only Model (No Scripts)
- ✅ SHA256 Integrity Verification
- ✅ Minified Production Assets
- ✅ Environment-Specific Configuration
- ✅ Automated Security Scanning

### Runtime Security
- ✅ HTTPS Enforcement
- ✅ Token Expiration & Rotation
- ✅ Audit Logging
- ✅ Rate Limiting
- ✅ Input Validation & Sanitization

## API Endpoints

### OAuth Server
- `GET /` - Widget interface
- `GET /auth/github` - Initiate OAuth flow
- `GET /auth/callback` - OAuth callback
- `GET /chat` - Chat interface
- `POST /api/chat` - Chat API

### Widget Integration
- Single HTML file with embedded CSS/JS
- OAuth redirect handling
- JWT token management
- Real-time chat functionality

## Monitoring & Maintenance

### Security Monitoring
- Token usage tracking
- Failed authentication attempts
- Organization membership changes
- Suspicious activity detection

### Performance Monitoring
- Response time tracking
- Error rate monitoring
- User session analytics
- API usage metrics

### Maintenance Procedures
- Token rotation (30-day expiration)
- Security updates
- Dependency updates
- Backup procedures

## Compliance & Governance

### Data Protection
- Minimal data collection (GitHub user ID, org membership)
- JWT tokens with expiration
- Secure token storage (client-side only)
- No persistent user data storage

### Audit Trail
- Authentication events logging
- API usage tracking
- Security incident logging
- Compliance reporting

## Deployment Checklist

- [ ] GitHub OAuth App created and configured
- [ ] OAuth server environment variables set
- [ ] OAuth server deployed and tested
- [ ] Widget artifacts built and verified
- [ ] Widget deployed to target environment
- [ ] DNS configured for widget domain
- [ ] SSL certificates installed
- [ ] Security scanning completed
- [ ] Integration testing passed
- [ ] Monitoring and alerting configured

## Troubleshooting

### Common Issues

1. **OAuth Callback Errors:**
   - Verify callback URL in GitHub OAuth app
   - Check OAuth server logs
   - Validate PKCE implementation

2. **Token Validation Failures:**
   - Check JWT secret consistency
   - Verify token expiration
   - Validate organization membership

3. **Widget Loading Issues:**
   - Verify artifact integrity
   - Check CORS configuration
   - Validate OAuth server URL

### Security Incident Response

1. **Token Compromise:**
   - Immediately revoke OAuth app
   - Rotate JWT secrets
   - Notify affected users
   - Audit access logs

2. **Unauthorized Access:**
   - Review organization membership
   - Update authorization logic
   - Implement additional verification

3. **Deployment Compromise:**
   - Rebuild artifacts from clean source
   - Verify integrity checksums
   - Update deployment pipeline

## Future Enhancements

- Multi-organization support
- Advanced AI capabilities integration
- Mobile app support
- Voice interface
- Multi-language support
- Advanced analytics dashboard
