#!/usr/bin/env python3
"""
PHI Command Center Demo - BIMS Financial System
Enterprise Financial Management Dashboard
Port: 5000
"""

from flask import Flask, jsonify, render_template_string, request
from flask_cors import CORS
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Demo Data
COMPANIES = [
    {"id": 1, "name": "Fractal5 Solutions", "industry": "Technology", "revenue": 2500000},
    {"id": 2, "name": "Dominion Enterprises", "industry": "Financial Services", "revenue": 5000000},
    {"id": 3, "name": "PHI Analytics Corp", "industry": "AI & Data Science", "revenue": 1750000}
]

ACCOUNTS = [
    {"id": 1, "code": "1000", "name": "Cash", "type": "Asset", "balance": 150000},
    {"id": 2, "code": "1200", "name": "Accounts Receivable", "type": "Asset", "balance": 75000},
    {"id": 3, "code": "2000", "name": "Accounts Payable", "type": "Liability", "balance": 50000},
    {"id": 4, "code": "3000", "name": "Equity", "type": "Equity", "balance": 100000},
    {"id": 5, "code": "4000", "name": "Revenue", "type": "Revenue", "balance": 200000}
]

TRANSACTIONS = [
    {"id": 1, "date": "2026-03-01", "description": "Client Payment", "amount": 50000, "account": "Cash"},
    {"id": 2, "date": "2026-03-05", "description": "Service Revenue", "amount": 75000, "account": "Revenue"},
    {"id": 3, "date": "2026-03-06", "description": "Vendor Payment", "amount": 25000, "account": "Accounts Payable"}
]

FINANCIAL_STATEMENTS = [
    {
        "type": "Balance Sheet",
        "date": "2026-03-07",
        "assets": 225000,
        "liabilities": 50000,
        "equity": 175000
    },
    {
        "type": "Income Statement",
        "period": "Q1 2026",
        "revenue": 200000,
        "expenses": 125000,
        "net_income": 75000
    },
    {
        "type": "Cash Flow Statement",
        "period": "Q1 2026",
        "operating": 85000,
        "investing": -25000,
        "financing": 15000,
        "net_cash_flow": 75000
    }
]

# HTML Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PHI Command Center - BIMS Financial System</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #e8e8e8;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        h1 {
            text-align: center;
            color: #00d9ff;
            margin-bottom: 10px;
            font-size: 2.5em;
            text-shadow: 0 0 20px rgba(0, 217, 255, 0.5);
        }
        .subtitle {
            text-align: center;
            color: #a8dadc;
            margin-bottom: 30px;
            font-size: 1.2em;
        }
        .status {
            background: rgba(0, 217, 255, 0.1);
            border: 2px solid #00d9ff;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 30px;
            text-align: center;
        }
        .status-badge {
            display: inline-block;
            background: #00d9ff;
            color: #1a1a2e;
            padding: 5px 15px;
            border-radius: 4px;
            font-weight: bold;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(0, 217, 255, 0.3);
            border-radius: 12px;
            padding: 20px;
            backdrop-filter: blur(10px);
            transition: transform 0.3s, box-shadow 0.3s;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0, 217, 255, 0.3);
        }
        .card-title {
            color: #00d9ff;
            font-size: 1.3em;
            margin-bottom: 15px;
            border-bottom: 2px solid rgba(0, 217, 255, 0.3);
            padding-bottom: 10px;
        }
        .metric {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        .metric:last-child { border-bottom: none; }
        .metric-label { color: #a8dadc; }
        .metric-value {
            color: #00ff9f;
            font-weight: bold;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        th {
            background: rgba(0, 217, 255, 0.2);
            color: #00d9ff;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px 12px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        tr:hover {
            background: rgba(0, 217, 255, 0.1);
        }
        .endpoint-list {
            background: rgba(0, 0, 0, 0.3);
            padding: 15px;
            border-radius: 8px;
            margin-top: 10px;
        }
        .endpoint {
            padding: 8px;
            margin: 5px 0;
            background: rgba(0, 217, 255, 0.1);
            border-left: 3px solid #00d9ff;
            padding-left: 12px;
            color: #a8dadc;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ PHI COMMAND CENTER ⚡</h1>
        <div class="subtitle">Enterprise BIMS Financial Management System</div>
        
        <div class="status">
            <span class="status-badge">✅ SYSTEM OPERATIONAL</span>
            <div style="margin-top: 10px; color: #a8dadc;">
                Last Updated: {{ timestamp }} | Endpoint: {{ host }} | Status: Live
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h2 class="card-title">📊 Companies</h2>
                <div class="metric">
                    <span class="metric-label">Total Companies:</span>
                    <span class="metric-value">{{ companies|length }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Total Revenue:</span>
                    <span class="metric-value">${{ total_revenue }}</span>
                </div>
                <table>
                    <tr><th>Company</th><th>Industry</th><th>Revenue</th></tr>
                    {% for c in companies %}
                    <tr>
                        <td>{{ c.name }}</td>
                        <td>{{ c.industry }}</td>
                        <td>${{ c.revenue }}</td>
                    </tr>
                    {% endfor %}
                </table>
            </div>
            
            <div class="card">
                <h2 class="card-title">💰 Chart of Accounts</h2>
                <div class="metric">
                    <span class="metric-label">Total Accounts:</span>
                    <span class="metric-value">{{ accounts|length }}</span>
                </div>
                <table>
                    <tr><th>Code</th><th>Account</th><th>Type</th><th>Balance</th></tr>
                    {% for a in accounts %}
                    <tr>
                        <td>{{ a.code }}</td>
                        <td>{{ a.name }}</td>
                        <td>{{ a.type }}</td>
                        <td>${{ a.balance }}</td>
                    </tr>
                    {% endfor %}
                </table>
            </div>
            
            <div class="card">
                <h2 class="card-title">📝 Recent Transactions</h2>
                <table>
                    <tr><th>Date</th><th>Description</th><th>Amount</th></tr>
                    {% for t in transactions %}
                    <tr>
                        <td>{{ t.date }}</td>
                        <td>{{ t.description }}</td>
                        <td>${{ t.amount }}</td>
                    </tr>
                    {% endfor %}
                </table>
            </div>
            
            <div class="card">
                <h2 class="card-title">📈 Financial Statements</h2>
                {% for fs in financial_statements %}
                <div class="metric">
                    <span class="metric-label">{{ fs.type }}:</span>
                    <span class="metric-value">✅ Available</span>
                </div>
                {% endfor %}
            </div>
        </div>
        
        <div class="card">
            <h2 class="card-title">🔌 API Endpoints</h2>
            <div class="endpoint-list">
                <div class="endpoint">GET / - Dashboard (this page)</div>
                <div class="endpoint">GET /api/companies - Retrieve companies data</div>
                <div class="endpoint">GET /api/accounts - Retrieve chart of accounts</div>
                <div class="endpoint">GET /api/transactions - Retrieve transaction history</div>
                <div class="endpoint">GET /api/financial-statements - Retrieve financial statements</div>
                <div class="endpoint">GET /health - Health check endpoint</div>
                <div class="endpoint">GET /healthz - Health check endpoint</div>
            </div>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def dashboard():
    total_revenue = sum(c['revenue'] for c in COMPANIES)
    return render_template_string(
        HTML_TEMPLATE,
        companies=COMPANIES,
        accounts=ACCOUNTS,
        transactions=TRANSACTIONS,
        financial_statements=FINANCIAL_STATEMENTS,
        host=request.host,
        total_revenue=f"{total_revenue:,}",
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    )

@app.route('/api/companies')
def api_companies():
    return jsonify(COMPANIES)

@app.route('/api/accounts')
def api_accounts():
    return jsonify(ACCOUNTS)

@app.route('/api/transactions')
def api_transactions():
    return jsonify(TRANSACTIONS)

@app.route('/api/financial-statements')
def api_financial_statements():
    return jsonify(FINANCIAL_STATEMENTS)

@app.route('/healthz')
def healthz():
    return jsonify({
        "status": "healthy",
        "service": "PHI Command Center - BIMS",
        "timestamp": datetime.now().isoformat(),
        "port": int(os.environ.get('PORT', 5000))
    })


@app.route('/health')
def health():
    return healthz()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"🚀 Starting PHI Command Center BIMS on port {port}")
    print(f"📊 Dashboard: http://localhost:{port}")
    print(f"🔌 API: http://localhost:{port}/api/")
    app.run(host='0.0.0.0', port=port, debug=False)
