// modules/local/plot_abundances.nf
// Generate abundance visualizations

process PLOT_ABUNDANCES {
    label 'process_low'
    label 'wfnanoclust'

    publishDir "${params.out_dir}/abundances", mode: 'copy'

    input:
        path abundance_files

    output:
        path "*.png", emit: plots
        path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import pandas as pd
    import numpy as np
    from pathlib import Path

    def create_barplot(df, level, output_file, top_n=20):
        \"\"\"Create stacked bar plot for abundances\"\"\"
        if df.empty:
            # Create empty plot
            fig, ax = plt.subplots(figsize=(10, 6))
            ax.text(0.5, 0.5, 'No data available', ha='center', va='center', fontsize=14)
            ax.set_xlim(0, 1)
            ax.set_ylim(0, 1)
            plt.savefig(output_file, dpi=150, bbox_inches='tight')
            plt.close()
            return
        
        # Get top N taxa
        df_sorted = df.nlargest(top_n, 'relative_abundance')
        
        # Create horizontal bar plot
        fig, ax = plt.subplots(figsize=(12, max(6, len(df_sorted) * 0.4)))
        
        colors = plt.cm.Spectral(np.linspace(0, 1, len(df_sorted)))
        
        y_pos = np.arange(len(df_sorted))
        bars = ax.barh(y_pos, df_sorted['relative_abundance'] * 100, color=colors)
        
        ax.set_yticks(y_pos)
        ax.set_yticklabels(df_sorted[level])
        ax.invert_yaxis()
        ax.set_xlabel('Relative Abundance (%)')
        ax.set_title(f'Top {min(top_n, len(df_sorted))} Taxa at {level.capitalize()} Level')
        
        # Add percentage labels on bars
        for bar, pct in zip(bars, df_sorted['relative_abundance'] * 100):
            ax.text(bar.get_width() + 0.5, bar.get_y() + bar.get_height()/2,
                   f'{pct:.1f}%', va='center', fontsize=8)
        
        plt.tight_layout()
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
        plt.close()

    def create_pie_chart(df, level, output_file, top_n=10):
        \"\"\"Create pie chart for abundances\"\"\"
        if df.empty:
            fig, ax = plt.subplots(figsize=(8, 8))
            ax.text(0.5, 0.5, 'No data available', ha='center', va='center', fontsize=14)
            plt.savefig(output_file, dpi=150, bbox_inches='tight')
            plt.close()
            return
        
        # Get top N taxa and group others
        df_sorted = df.nlargest(top_n, 'relative_abundance')
        other_sum = df[~df[level].isin(df_sorted[level])]['relative_abundance'].sum()
        
        labels = list(df_sorted[level])
        sizes = list(df_sorted['relative_abundance'])
        
        if other_sum > 0:
            labels.append('Other')
            sizes.append(other_sum)
        
        # Create pie chart
        fig, ax = plt.subplots(figsize=(10, 8))
        colors = plt.cm.Spectral(np.linspace(0, 1, len(labels)))
        
        wedges, texts, autotexts = ax.pie(
            sizes, labels=labels, autopct='%1.1f%%',
            colors=colors, pctdistance=0.85
        )
        
        # Improve text readability
        for text in texts:
            text.set_fontsize(9)
        for autotext in autotexts:
            autotext.set_fontsize(8)
        
        ax.set_title(f'Taxonomic Composition at {level.capitalize()} Level')
        plt.tight_layout()
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
        plt.close()

    # Process each abundance file
    files = "${abundance_files}".split()
    
    for f in files:
        path = Path(f)
        if not path.exists() or not f.endswith('.tsv'):
            continue
        
        # Extract level from filename (abundance_genus.tsv -> genus)
        level = path.stem.replace('abundance_', '')
        
        print(f"Processing {level} abundance data...")
        
        try:
            df = pd.read_csv(path, sep='\\t')
            
            if not df.empty and level in df.columns:
                # Create bar plot
                create_barplot(df, level, f'abundance_{level}_barplot.png')
                
                # Create pie chart for genus and species only
                if level in ['genus', 'species']:
                    create_pie_chart(df, level, f'abundance_{level}_pie.png')
                
                print(f"  Created plots for {level}")
            else:
                print(f"  Skipping {level} (empty or missing column)")
        except Exception as e:
            print(f"  Error processing {level}: {e}")

    print("Plot generation complete")
    """

    stub:
    """
    touch abundance_genus_barplot.png
    touch abundance_species_barplot.png
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
        matplotlib: \$(python -c "import matplotlib; print(matplotlib.__version__)")
        pandas: \$(python -c "import pandas; print(pandas.__version__)")
    END_VERSIONS
    """
}
