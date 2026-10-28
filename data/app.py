import json
import os
import ssl
import urllib.request
from datetime import datetime, timedelta, timezone

import certifi
import pandas as pd
import streamlit as st

from seismic_score import (
    classify_permeability, classify_pathways, classify_roughness,
    classify_size, classify_continuity, classify_stress,
    classify_proximity, classify_caprock,
    risk_score, d_value,
)

st.set_page_config(page_title="Induced Seismicity Risk Screener", layout="wide")

PARAM_KEYS = ["perm", "path", "rough", "size", "cont", "stress", "prox", "cap"]


# ============================================================ live USGS data

@st.cache_data(ttl=900)
def fetch_oklahoma_seismicity(days=30):
    """Recent earthquakes in Oklahoma from the USGS FDSN event service.

    Oklahoma is one of the best-documented cases of injection-induced
    seismicity, so this is live context for the problem the tool screens for.
    Returns (DataFrame, error message or None).
    """
    start = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
    url = (
        "https://earthquake.usgs.gov/fdsnws/event/1/query"
        f"?format=geojson&starttime={start}"
        "&minlatitude=33.5&maxlatitude=37.1"
        "&minlongitude=-103.1&maxlongitude=-94.4"
        "&minmagnitude=1.5"
    )
    request = urllib.request.Request(
        url, headers={"User-Agent": "ccs-seismicity-screener/1.0"}
    )
    # macOS Python does not read the system certificate store, so point
    # urllib at certifi's CA bundle instead of disabling verification.
    context = ssl.create_default_context(cafile=certifi.where())
    try:
        with urllib.request.urlopen(request, timeout=20,
                                    context=context) as response:
            data = json.load(response)
    except Exception as exc:
        return pd.DataFrame(), f"{type(exc).__name__}: {exc}"

    rows = []
    for feature in data.get("features", []):
        lon, lat = feature["geometry"]["coordinates"][:2]
        rows.append({
            "lat": lat,
            "lon": lon,
            "mag": feature["properties"].get("mag"),
            "place": feature["properties"].get("place"),
        })

    df = pd.DataFrame(rows)
    # The query box is Oklahoma's bounding rectangle, but the state is not a
    # rectangle — drop events that USGS places in a neighbouring state.
    if not df.empty:
        df = df[df["place"].str.contains("Oklahoma", na=False)]
    return df, None


# ============================================================== input layer

def parameter_input(name, weight, key, classifier, unit=None, options=None,
                    threshold_note=""):
    """Render one parameter block in the sidebar. Pass `unit` for numeric
    inputs, `options` for categorical ones."""
    with st.sidebar:
        with st.expander(f"{name}  ·  w={weight}"):
            if threshold_note:
                st.caption(threshold_note)

            mode = st.radio(
                "Input mode",
                ["Enter data", "Choose risk level", "Unknown"],
                key=key + "_mode",
            )

            if mode == "Enter data":
                if unit:
                    value = st.number_input(f"{name} ({unit})", key=key + "_val")
                    level = classifier(value)
                else:
                    answer = st.selectbox("Select", options, key=key + "_ans")
                    level = classifier(answer)
            elif mode == "Choose risk level":
                level = st.selectbox(
                    "Risk level", ["high", "moderate", "low"], key=key + "_lvl"
                )
            else:
                level = "na"

            st.caption(f"→ {level}")

    return (name, weight, level)


# ================================================================== presets

PRESETS = {
    "Blank / custom site": {
        "perm_mode": "Unknown",
        "path_mode": "Unknown",
        "rough_mode": "Unknown",
        "size_mode": "Unknown",
        "cont_mode": "Unknown",
        "stress_mode": "Unknown",
        "prox_mode": "Unknown",
        "cap_mode": "Unknown",
    },
    "Illinois Basin-Decatur": {
        "perm_mode": "Enter data",          "perm_val": 0.1013,
        "path_mode": "Enter data",          "path_ans": "yes",
        "rough_mode": "Unknown",
        "size_mode": "Choose risk level",   "size_lvl": "low",
        "cont_mode": "Enter data",          "cont_ans": "continuous",
        "stress_mode": "Choose risk level", "stress_lvl": "high",
        "prox_mode": "Enter data",          "prox_val": 2.2,
        "cap_mode": "Enter data",           "cap_val": 125.0,
    },
    "In Salah": {
        "perm_mode": "Enter data",          "perm_val": 4.75,
        "path_mode": "Enter data",          "path_ans": "yes",
        "rough_mode": "Enter data",         "rough_ans": "smooth",
        "size_mode": "Enter data",          "size_val": 4000.0,
        "cont_mode": "Enter data",          "cont_ans": "continuous",
        "stress_mode": "Enter data",        "stress_val": 0.4,
        "prox_mode": "Enter data",          "prox_val": 3.1,
        "cap_mode": "Enter data",           "cap_val": 950.0,
    },
    "Basel": {
        "perm_mode": "Enter data",          "perm_val": 0.005877,
        "path_mode": "Enter data",          "path_ans": "yes",
        "rough_mode": "Enter data",         "rough_ans": "rough",
        "size_mode": "Enter data",          "size_val": 1000.0,
        "cont_mode": "Enter data",          "cont_ans": "continuous",
        "stress_mode": "Enter data",        "stress_val": 0.7,
        "prox_mode": "Enter data",          "prox_val": 2.12,
        "cap_mode": "Choose risk level",    "cap_lvl": "high",
    },
}


# =========================================================== page: overview

def render_landing():
    st.title("CO₂ Storage — Induced Seismicity Risk Screener")
    st.subheader("Screening injection sites before the first CO₂ goes underground")

    events, err = fetch_oklahoma_seismicity()

    if err:
        st.caption(f"Live seismicity feed unavailable — {err}")
    elif not events.empty:
        mags = events["mag"].dropna()
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Events, past 30 days", len(events))
        c2.metric("Largest magnitude", f"M{mags.max():.1f}" if len(mags) else "—")
        c3.metric("Region", "Oklahoma")
        c4.metric("Source", "USGS, live")

        st.caption(
            "Recent M≥1.5 seismicity in Oklahoma. Before 2009 the state averaged "
            "about one M3+ earthquake a year; by 2015, at the peak of wastewater "
            "disposal, it averaged more than two a day. Injection volumes were cut "
            "by regulation starting in 2015 and rates have fallen since. Not every "
            "event above is induced — but injection-induced seismicity is both real "
            "and manageable, which is the case for screening sites before injection "
            "begins."
        )
        st.map(events[["lat", "lon"]], height=260)

    st.divider()

    left, right = st.columns([3, 2])

    with left:
        st.markdown("""
### The gap this fills

Carbon storage only works if the CO₂ stays put — and if injecting it doesn't
shake the ground. But the tools that forecast induced seismicity (ORION,
TOUGH-FLAC, ECLIPSE) all need **operational data**: injection rate, pressure,
volume. None of that exists before a site starts injecting.

This tool screens a candidate site using **only geological parameters**
available during pre-injection characterization — eight of them, each with a
threshold and a weight drawn from peer-reviewed literature.

**Handling missing data**

Real site characterization is incomplete. Unknown parameters drop out of
*both* the numerator and the denominator, so absent data reduces coverage
instead of skewing the score. A site with five known parameters still gets a
meaningful number.
        """)

    with right:
        if os.path.exists("validation_plot.png"):
            st.image(
                "validation_plot.png",
                caption="Retrospective validation against three injection projects",
            )
        else:
            st.info("Validation figure not found — run `make_figure.py` "
                    "to generate it.")

    st.divider()

    col_a, col_b = st.columns([3, 1])
    with col_a:
        if st.button("Launch the screener  →", type="primary",
                     use_container_width=True):
            st.switch_page(tool_page)
    with col_b:
        if st.button("Method & limitations", use_container_width=True):
            st.switch_page(method_page)

    st.caption("Screening aid only — not a substitute for site-specific "
               "geomechanical modeling.")


# ============================================================= page: method

def render_method():
    st.title("Method & validation")

    t1, t2, t3 = st.tabs(["Formula", "Parameters & thresholds",
                          "Validation & limits"])

    with t1:
        st.markdown("Each parameter contributes a determination value `d`, "
                    "weighted by `w`, gated by an availability flag `a`:")
        st.latex(r"\text{Risk Score (\%)} = "
                 r"\frac{\sum a_i \cdot w_i \cdot d_i}{\sum a_i \cdot w_i} \times 100")
        st.markdown("""
- `d` = 1 (high) · 0.5 (moderate) · 0 (low)
- `w` = 2 for primary parameters, 1 for secondary
- `a` = 1 if data is available, 0 if not

Missing parameters are excluded from both the numerator and the denominator,
so absent data lowers the number of contributing parameters rather than
biasing the score in either direction.
        """)

    with t2:
        st.table({
            "Parameter": ["Fault permeability", "Fluid pathways", "Fault roughness",
                          "Fault size / length", "Fault continuity", "Stress state",
                          "Proximity to basement", "Caprock integrity"],
            "w": [2, 2, 1, 2, 2, 2, 2, 1],
            "Threshold": ["<1 mD → high · 1–100 → moderate · >100 → low",
                          "pathway present → high",
                          "rough / immature → high",
                          "<200 m → low · 200–1000 → moderate · ≥1000 → high",
                          "continuous → high",
                          "µmob ≥ 0.6 → high",
                          "<1 km → high",
                          "<50 m → high"],
            "Source": ["Cao et al. 2025", "Oye et al. 2022", "Wang et al. 2024",
                       "Rutqvist et al. 2016", "Rutqvist et al. 2016",
                       "Vilarrasa et al. 2019", "Skoumal et al. 2018",
                       "CO₂CRC et al. 2013"],
        })

    with t3:
        st.markdown("""
| Site | Risk score | Recorded events | Mmax |
|---|---|---|---|
| Illinois Basin-Decatur | 61.54% | 221 | 1.2 |
| In Salah | 50.00% | 9506 | 1.7 |
| Basel | 85.71% | 10500 | 3.4 |

**What this shows.** The framework separates Basel — the one case with felt
seismicity — clearly from the other two. It does **not** correctly order
Illinois Basin-Decatur against In Salah. That inversion is stable under an
equal-weighting scheme and under sensitivity analysis, which suggests it
reflects the framework rather than one bad data point. One likely factor:
recorded event counts may track monitoring network density as much as hazard.

**Known limitations**

- Basel is an Enhanced Geothermal System (water injection), not CO₂ storage.
  It is included because it is one of the few well-documented injection-induced
  sequences with felt events, but the fluid properties and reservoir mechanics
  differ from supercritical CO₂ injection.
- Three cases is a small validation set.
- Several parameters were assigned from qualitative descriptions in the
  literature rather than measured values that could be tested against a
  threshold directly.
- Primary/secondary assignment rests on the descriptive verbs authors use
  ("determine" vs. "influence"), which involves judgment.
        """)

    st.divider()
    if st.button("Launch the screener  →", type="primary"):
        st.switch_page(tool_page)


# =============================================================== page: tool

def render_tool():
    st.title("Screener")
    st.caption("Pre-injection geological screening · 8 parameters · "
               "literature-derived thresholds")

    with st.sidebar:
        st.subheader("Start from")
        for case_name in PRESETS:
            if st.button(case_name, use_container_width=True):
                for k, v in PRESETS[case_name].items():
                    st.session_state[k] = v
                st.rerun()
        st.divider()
        st.subheader("Site parameters")

    entries = [
        parameter_input(
            "Fault permeability", 2, "perm", classify_permeability,
            unit="mD",
            threshold_note="<1 mD → high · 1–100 → moderate · >100 → low"),
        parameter_input(
            "Fluid pathways", 2, "path", classify_pathways,
            options=["yes", "no"],
            threshold_note="pathway present → high"),
        parameter_input(
            "Fault roughness", 1, "rough", classify_roughness,
            options=["rough", "smooth"],
            threshold_note="rough / immature → high (Wang et al. 2024)"),
        parameter_input(
            "Fault size / length", 2, "size", classify_size,
            unit="m",
            threshold_note="<200 m → low · 200–1000 → moderate · ≥1000 → high"),
        parameter_input(
            "Fault continuity", 2, "cont", classify_continuity,
            options=["continuous", "heterogeneous"],
            threshold_note="continuous → high"),
        parameter_input(
            "Stress state", 2, "stress", classify_stress,
            unit="µmob",
            threshold_note="µmob ≥ 0.6 → high"),
        parameter_input(
            "Proximity to basement", 2, "prox", classify_proximity,
            unit="km",
            threshold_note="<1 km → high"),
        parameter_input(
            "Caprock integrity", 1, "cap", classify_caprock,
            unit="m",
            threshold_note="<50 m → high"),
    ]

    simple = []
    for name, weight, level in entries:
        simple.append((weight, level))
    score = risk_score(simple)

    num = sum(w * d_value(l) for n, w, l in entries if l != "na")
    den = sum(w for n, w, l in entries if l != "na")
    used = sum(1 for n, w, l in entries if l != "na")

    if score is None:
        st.warning("No data entered — load a case or enter parameters "
                   "in the sidebar.")
        return

    col1, col2 = st.columns([1, 2])
    with col1:
        st.metric("Risk Score", f"{round(score, 2)} %")
    with col2:
        st.progress(score / 100)
        st.caption(f"{round(num, 1)} of {den} weighted points · "
                   f"{used} of 8 parameters")

    st.divider()
    st.subheader("Parameter breakdown")

    icons = {"high": "🔴", "moderate": "🟡", "low": "🟢"}
    for name, weight, level in entries:
        if level == "na":
            st.write(f"⚪ **{name}** — no data (excluded)")
        else:
            contribution = weight * d_value(level)
            st.write(f"{icons[level]} **{name}** — {level} · "
                     f"{contribution}/{weight}")

    st.divider()
    st.caption("Screening aid only — not a substitute for site-specific "
               "geomechanical modeling. Missing parameters are excluded from "
               "both numerator and denominator.")


# ===================================================================== main

overview_page = st.Page(render_landing, title="Overview",
                        url_path="overview", default=True)
tool_page = st.Page(render_tool, title="Screener", url_path="screener")
method_page = st.Page(render_method, title="Method", url_path="method")

if "perm_mode" not in st.session_state:
    for key in PARAM_KEYS:
        st.session_state[key + "_mode"] = "Unknown"

pg = st.navigation([overview_page, tool_page, method_page])
pg.run()
