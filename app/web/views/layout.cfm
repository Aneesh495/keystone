<cfparam name="viewTitle" default="Dashboard">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>KEYSTONE :: <cfoutput>#encodeForHTML(viewTitle)#</cfoutput></title>
    <style>
        :root {
            --bg-canvas: #090d16;
            --bg-surface: #111827;
            --bg-card: #1f2937;
            --border-color: #374151;
            --text-primary: #f9fafb;
            --text-secondary: #9ca3af;
            --accent-blue: #3b82f6;
            --accent-cyan: #06b6d4;
            --accent-emerald: #10b981;
            --accent-amber: #f59e0b;
            --accent-rose: #f43f5e;
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: var(--bg-canvas);
            color: var(--text-primary);
            font-family: var(--font-sans);
            font-size: 14px;
            line-height: 1.5;
            display: flex;
            min-height: 100vh;
        }

        /* Sidebar Navigation */
        aside.sidebar {
            width: 250px;
            background-color: var(--bg-surface);
            border-right: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            padding: 24px 16px;
            flex-shrink: 0;
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 32px;
            padding-left: 8px;
        }

        .brand-logo {
            width: 32px;
            height: 32px;
            background: linear-gradient(135deg, var(--accent-blue), var(--accent-cyan));
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 800;
            color: #fff;
            font-family: var(--font-mono);
        }

        .brand-text h1 {
            font-size: 16px;
            font-weight: 700;
            letter-spacing: 1px;
            text-transform: uppercase;
        }

        .brand-text span {
            font-size: 11px;
            color: var(--accent-cyan);
            font-family: var(--font-mono);
        }

        nav.nav-menu {
            display: flex;
            flex-direction: column;
            gap: 6px;
            flex-grow: 1;
        }

        nav.nav-menu a {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 12px;
            border-radius: 6px;
            color: var(--text-secondary);
            text-decoration: none;
            font-weight: 500;
            transition: all 0.15s ease;
        }

        nav.nav-menu a:hover, nav.nav-menu a.active {
            background-color: var(--bg-card);
            color: #fff;
        }

        nav.nav-menu a.active {
            border-left: 3px solid var(--accent-blue);
        }

        .sidebar-footer {
            padding-top: 16px;
            border-top: 1px solid var(--border-color);
            font-size: 12px;
            color: var(--text-secondary);
            font-family: var(--font-mono);
        }

        /* Main Workspace Container */
        main.content-area {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            overflow-y: auto;
        }

        header.top-header {
            height: 64px;
            background-color: var(--bg-surface);
            border-bottom: 1px solid var(--border-color);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 32px;
        }

        .page-title {
            font-size: 18px;
            font-weight: 600;
        }

        .header-status {
            display: flex;
            align-items: center;
            gap: 16px;
        }

        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 10px;
            border-radius: 9999px;
            font-size: 12px;
            font-family: var(--font-mono);
            font-weight: 600;
            background-color: rgba(16, 185, 129, 0.15);
            color: var(--accent-emerald);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background-color: var(--accent-emerald);
        }

        .container {
            padding: 32px;
            max-width: 1400px;
            width: 100%;
        }

        /* Utility Elements */
        .grid-kpi {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 20px;
            margin-bottom: 32px;
        }

        .card {
            background-color: var(--bg-surface);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
        }

        .card-label {
            font-size: 12px;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            font-weight: 600;
            margin-bottom: 8px;
        }

        .card-value {
            font-size: 26px;
            font-weight: 700;
            font-family: var(--font-mono);
        }

        .card-subtext {
            font-size: 12px;
            color: var(--text-secondary);
            margin-top: 6px;
        }

        .data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }

        .data-table th {
            text-align: left;
            padding: 12px 16px;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--border-color);
            font-weight: 600;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .data-table td {
            padding: 14px 16px;
            border-bottom: 1px solid var(--border-color);
        }

        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            font-family: var(--font-mono);
        }
        .badge-x12 { background-color: rgba(59, 130, 246, 0.2); color: var(--accent-blue); }
        .badge-edifact { background-color: rgba(6, 182, 212, 0.2); color: var(--accent-cyan); }
        .badge-hl7 { background-color: rgba(16, 185, 129, 0.2); color: var(--accent-emerald); }
        .badge-iso { background-color: rgba(245, 158, 11, 0.2); color: var(--accent-amber); }
        .badge-success { background-color: rgba(16, 185, 129, 0.2); color: var(--accent-emerald); }
        .badge-fail { background-color: rgba(244, 63, 94, 0.2); color: var(--accent-rose); }
    </style>
</head>
<body>
    <aside class="sidebar">
        <div class="brand">
            <div class="brand-logo">K</div>
            <div class="brand-text">
                <h1>Keystone</h1>
                <span>B2B Transaction Mesh</span>
            </div>
        </div>
        <nav class="nav-menu">
            <a href="index.cfm" class="<cfif url.view eq '' or url.view eq 'dashboard'>active</cfif>">
                <span>Dashboard</span>
            </a>
            <a href="index.cfm?view=transactions" class="<cfif url.view eq 'transactions'>active</cfif>">
                <span>Transactions</span>
            </a>
            <a href="index.cfm?view=sagas" class="<cfif url.view eq 'sagas'>active</cfif>">
                <span>Saga Workflows</span>
            </a>
            <a href="index.cfm?view=dlq" class="<cfif url.view eq 'dlq'>active</cfif>">
                <span>Dead Letter Queue</span>
            </a>
            <a href="index.cfm?view=pipelines" class="<cfif url.view eq 'pipelines'>active</cfif>">
                <span>Pipelines</span>
            </a>
            <a href="index.cfm?view=partners" class="<cfif url.view eq 'partners'>active</cfif>">
                <span>Trading Partners</span>
            </a>
            <a href="/api/v1/metrics" target="_blank">
                <span>Metrics (Prometheus)</span>
            </a>
        </nav>
        <div class="sidebar-footer">
            <div>CFML Engine: Lucee 5.4</div>
            <div>Gateway Node: Node-01</div>
        </div>
    </aside>

    <main class="content-area">
        <header class="top-header">
            <div class="page-title"><cfoutput>#encodeForHTML(viewTitle)#</cfoutput></div>
            <div class="header-status">
                <div class="status-pill">
                    <span class="status-dot"></span>
                    <span>MESH ONLINE</span>
                </div>
            </div>
        </header>
