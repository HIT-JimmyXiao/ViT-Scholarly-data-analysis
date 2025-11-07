# DIY: Academic Landscape Explorer - Vision Transformer Scholarly Atlas

<p align="center">
  <img src="https://img.shields.io/badge/ViT%20Scholarly%20Atlas-EDA%20for%20Web%20of%20Science-blue" alt="ViT Scholarly Atlas" width="480"/>
  <br/><br/>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-green"></a>
  <a href="https://github.com/your-account/ViT-Scholarly-Atlas/releases"><img alt="Release" src="https://img.shields.io/badge/version-1.0.0-blue"></a>
  <a href="#core-visualizations"><img alt="Visualizations" src="https://img.shields.io/badge/dashboards-6%20plots-orange"></a>
  <a href="report_EN.Rmd"><img alt="R Markdown" src="https://img.shields.io/badge/RMarkdown-English-success"></a>
</p>

<h4 align="center">
  <b>English</b> |
  <a href="README.md">简体中文</a>
</h4>

---

## 📋 Project Overview

This repository reproduces the entire analytical pipeline of the “Vision Transformer Scholarly Atlas” project:

- **Data Source**: 2,000 ViT-related publications exported from Web of Science (`savedrecs (1).xls` + `savedrecs (2).xls`).
- **Tooling**: R + tidyverse (all code embedded in `report_CN.Rmd` and `report_EN.Rmd`).
- **Key Deliverables**: Six analytical modules covering annual output, top journals/countries, citation patterns, keyword evolution, collaboration profiles, and impact clustering.

Artifacts such as plots and HTML reports live in `./visualization/` and optional `./output/` folders.

---

## 🗂️ Data Snapshot

| Metric | Value | Notes |
| --- | --- | --- |
| Publication Count | 2,000 | After merge & dedup |
| Raw Fields | 79 columns | Contain multilingual & sparse fields |
| Retained Fields | ~22 columns | Columns with >50% missing removed |
| Publication Years | 2018-2025 | Q1=2019, Median=2021, Q3=2023 |
| Citations (WoS Core) | Mean 12.13, Max 334 | Long-tail distribution |
| Authors per Paper | Mean 4.6 | Collaboration-driven |

> Detailed field mapping and dropped columns are documented in `submit/README.md`.

---

## 📊 Core Visualizations {#core-visualizations}

- Annual Publication Trend

  ![Annual Trend](./visualization/plot1_annual_trend.png)

- Top Journals

  ![Top Journals](./visualization/plot2_top_journals.png)

- Citation Distribution

  ![Citation Distribution](./visualization/plot3_citation_distribution.png)

- Top Keywords

  ![Top Keywords](./visualization/plot4_top_keywords.png)

- Keyword Temporal Evolution

  ![Keyword Trends](./visualization/plot5_keyword_trends.png)

- Collaboration & Clustering Profiles

  ![Collaboration](./visualization/plot_author_collaboration.png)

> Additional figures: `./visualization/plot_cluster_characteristics.png`, etc.

---

## 🔍 Key Insights

1. **Explosive Growth**: Publication volume surged by 60%+ in 2022-2023 and remains high through 2025.
2. **Cross-domain Adoption**: High-frequency ViT papers appear in multimedia, communications, and medical journals, signalling broad adoption.
3. **Long-tail Citations**: Citations are heavily right-skewed; the top 5% papers contribute >30% of citations.
4. **Emerging Topics**: Core terms (`attention`, `classification`) persist while `medical`, `remote`, and `scene` grow rapidly after 2022.
5. **Collaboration Payoff**: Author count correlates positively with citation impact; cross-institution teams yield higher visibility.
6. **Impact Personas**: K-means + PCA reveal four research profiles—high-impact collaborative, emerging potential, steady mid-impact, and foundational exploration.

---

## 🧭 Repository Layout

```
github/
├── README.md             # Chinese overview
├── README_en.md          # English overview (this file)
├── report_CN.Rmd         # Chinese R Markdown report
├── report_EN.Rmd         # English R Markdown report
├── visualization/         # Rendered figures
└── savedrecs (1|2).xls   # Original WoS exports
```

---

## ⚙️ Getting Started

```bash
git clone https://github.com/your-account/ViT-Scholarly-Atlas.git
cd ViT-Scholarly-Atlas/submit

# Install dependencies
Rscript -e "install.packages(c('tidyverse','readxl','lubridate','scales','RColorBrewer','wordcloud','gridExtra'))"

# Render reports
Rscript -e "rmarkdown::render('report_CN.Rmd')"
Rscript -e "rmarkdown::render('report_EN.Rmd')"
```

The `cluster-visualization` chunk defaults to `eval = FALSE` to avoid potential hang during PCA plotting. Set it to `TRUE` if you need the scatter plot.

---

## 📌 Release Plan

| Version | Date | Highlights |
| --- | --- | --- |
| v1.0.0 | 2025-11-07 | Initial release with bilingual R Markdown and six primary visualizations |
| v1.1.0 | (Planned) | GitHub Actions auto-render + interactive dashboard add-ons |

---

## 📜 License

Distributed under the [MIT License](LICENSE).

---

## 📮 Contact

- GitHub: [https://github.com/your-account](https://github.com/your-account)
- Email: your.name@example.com

Issues and PRs are welcome—let’s map the Vision Transformer research landscape together!

