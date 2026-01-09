// modules/local/make_report.nf
// Generate comprehensive HTML report

process MAKE_REPORT {
    label 'process_low'
    label 'wfnanoclust'

    publishDir "${params.out_dir}", mode: 'copy'

    input:
        path qc_stats
        path umap_plots
        path abundance_files
        path abundance_plots
        path classification_files
        path versions
        val workflow_version

    output:
        path "wf-nanoclust-report.html", emit: html

    script:
    """
    #!/usr/bin/env python3
    import json
    import base64
    from pathlib import Path
    from datetime import datetime

    def encode_image(image_path):
        \"\"\"Encode image as base64 for embedding in HTML\"\"\"
        if not Path(image_path).exists():
            return None
        with open(image_path, 'rb') as f:
            return base64.b64encode(f.read()).decode('utf-8')

    def read_tsv(filepath):
        \"\"\"Read TSV file and return as list of dicts\"\"\"
        rows = []
        try:
            with open(filepath, 'r') as f:
                header = f.readline().strip().split('\\t')
                for line in f:
                    values = line.strip().split('\\t')
                    rows.append(dict(zip(header, values)))
        except:
            pass
        return rows

    def generate_html():
        # Collect data
        qc_data = []
        for f in "${qc_stats}".split():
            if Path(f).exists():
                qc_data.extend(read_tsv(f))
        
        # Collect abundance data
        abundance_data = {}
        for f in "${abundance_files}".split():
            path = Path(f)
            if path.exists() and f.endswith('.tsv'):
                level = path.stem.replace('abundance_', '')
                abundance_data[level] = read_tsv(f)
        
        # Collect images
        umap_images = []
        for f in "${umap_plots}".split():
            if Path(f).exists() and f.endswith('.png'):
                img_data = encode_image(f)
                if img_data:
                    umap_images.append(img_data)
        
        abundance_images = []
        for f in "${abundance_plots}".split():
            if Path(f).exists() and f.endswith('.png'):
                img_data = encode_image(f)
                if img_data:
                    abundance_images.append((Path(f).stem, img_data))
        
        # Read versions
        version_info = ""
        if Path("${versions}").exists():
            with open("${versions}", 'r') as f:
                version_info = f.read()
        
        # Generate HTML
        html = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>wf-nanoclust Report</title>
    <style>
        :root {
            --primary-color: #0091ea;
            --secondary-color: #00c853;
            --background: #f5f5f5;
            --card-bg: #ffffff;
            --text-color: #333333;
            --border-color: #e0e0e0;
        }
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: var(--background);
            color: var(--text-color);
            line-height: 1.6;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        header {
            background: linear-gradient(135deg, var(--primary-color), #00b0ff);
            color: white;
            padding: 30px;
            margin-bottom: 30px;
            border-radius: 8px;
        }
        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        header p {
            opacity: 0.9;
            font-size: 1.1em;
        }
        .card {
            background: var(--card-bg);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 25px;
            margin-bottom: 25px;
        }
        .card h2 {
            color: var(--primary-color);
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid var(--border-color);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
        }
        th {
            background: var(--background);
            font-weight: 600;
            color: var(--primary-color);
        }
        tr:hover {
            background: rgba(0, 145, 234, 0.05);
        }
        .image-container {
            text-align: center;
            margin: 20px 0;
        }
        .image-container img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }
        .image-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
        }
        .metric {
            display: inline-block;
            background: var(--background);
            padding: 15px 25px;
            border-radius: 8px;
            margin: 5px;
            text-align: center;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: var(--primary-color);
        }
        .metric-label {
            font-size: 0.9em;
            color: #666;
        }
        .version-info {
            font-size: 0.85em;
            color: #666;
            background: var(--background);
            padding: 15px;
            border-radius: 4px;
            font-family: monospace;
            white-space: pre-wrap;
        }
        footer {
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 0.9em;
        }
        .nav-tabs {
            display: flex;
            border-bottom: 2px solid var(--border-color);
            margin-bottom: 20px;
        }
        .nav-tab {
            padding: 10px 20px;
            cursor: pointer;
            border-bottom: 3px solid transparent;
            transition: all 0.3s;
        }
        .nav-tab:hover, .nav-tab.active {
            color: var(--primary-color);
            border-bottom-color: var(--primary-color);
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🧬 wf-nanoclust Report</h1>
            <p>De novo 16S/18S rRNA Clustering and Classification</p>
            <p>Generated: ''' + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + ''' | Version: ''' + "${workflow_version}" + '''</p>
        </header>
'''
        
        # QC Summary Section
        if qc_data:
            total_reads = sum(int(d.get('total_reads', 0)) for d in qc_data)
            passed_reads = sum(int(d.get('passed_reads', 0)) for d in qc_data)
            
            html += '''
        <div class="card">
            <h2>📊 Quality Control Summary</h2>
            <div style="display: flex; flex-wrap: wrap; justify-content: center;">
                <div class="metric">
                    <div class="metric-value">''' + f"{total_reads:,}" + '''</div>
                    <div class="metric-label">Total Reads</div>
                </div>
                <div class="metric">
                    <div class="metric-value">''' + f"{passed_reads:,}" + '''</div>
                    <div class="metric-label">Passed QC</div>
                </div>
                <div class="metric">
                    <div class="metric-value">''' + f"{100*passed_reads/total_reads:.1f}%" if total_reads > 0 else "N/A" + '''</div>
                    <div class="metric-label">Pass Rate</div>
                </div>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Sample</th>
                        <th>Total Reads</th>
                        <th>Passed</th>
                        <th>Failed (Length)</th>
                        <th>Failed (Quality)</th>
                        <th>Pass Rate</th>
                    </tr>
                </thead>
                <tbody>
'''
            for row in qc_data:
                html += f'''
                    <tr>
                        <td>{row.get('sample', 'N/A')}</td>
                        <td>{int(row.get('total_reads', 0)):,}</td>
                        <td>{int(row.get('passed_reads', 0)):,}</td>
                        <td>{int(row.get('failed_length', 0)):,}</td>
                        <td>{int(row.get('failed_quality', 0)):,}</td>
                        <td>{row.get('pass_rate', 'N/A')}%</td>
                    </tr>
'''
            html += '''
                </tbody>
            </table>
        </div>
'''
        
        # UMAP Clustering Section
        if umap_images:
            html += '''
        <div class="card">
            <h2>🔬 UMAP Clustering</h2>
            <p>Reads clustered using UMAP dimensionality reduction and HDBSCAN clustering algorithm.</p>
            <div class="image-grid">
'''
            for img in umap_images:
                html += f'''
                <div class="image-container">
                    <img src="data:image/png;base64,{img}" alt="UMAP Clustering Plot">
                </div>
'''
            html += '''
            </div>
        </div>
'''
        
        # Abundance Section
        if abundance_images:
            html += '''
        <div class="card">
            <h2>📈 Taxonomic Abundances</h2>
            <div class="image-grid">
'''
            for name, img in abundance_images:
                html += f'''
                <div class="image-container">
                    <h3>{name.replace('_', ' ').title()}</h3>
                    <img src="data:image/png;base64,{img}" alt="{name}">
                </div>
'''
            html += '''
            </div>
        </div>
'''
        
        # Abundance Tables
        for level in ['genus', 'species']:
            if level in abundance_data and abundance_data[level]:
                html += f'''
        <div class="card">
            <h2>📋 {level.capitalize()}-level Abundances</h2>
            <table>
                <thead>
                    <tr>
                        <th>{level.capitalize()}</th>
                        <th>Count</th>
                        <th>Relative Abundance</th>
                    </tr>
                </thead>
                <tbody>
'''
                for row in abundance_data[level][:20]:  # Top 20
                    html += f'''
                    <tr>
                        <td>{row.get(level, 'N/A')}</td>
                        <td>{row.get('count', 'N/A')}</td>
                        <td>{float(row.get('relative_abundance', 0))*100:.2f}%</td>
                    </tr>
'''
                html += '''
                </tbody>
            </table>
        </div>
'''
        
        # Version Info
        html += '''
        <div class="card">
            <h2>ℹ️ Software Versions</h2>
            <div class="version-info">''' + version_info + '''</div>
        </div>
        
        <footer>
            <p>Report generated by wf-nanoclust | Adapted from NanoCLUST for EPI2ME platform</p>
            <p>Citation: Rodríguez-Pérez H, Ciuffreda L, Flores C. Bioinformatics. 2021;37(11):1600-1601</p>
        </footer>
    </div>
</body>
</html>
'''
        return html

    # Generate and write report
    html_content = generate_html()
    with open("wf-nanoclust-report.html", 'w') as f:
        f.write(html_content)

    print("HTML report generated: wf-nanoclust-report.html")
    """

    stub:
    """
    touch wf-nanoclust-report.html
    """
}
