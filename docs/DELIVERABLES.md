# Deliverables

Five pieces, all built from the same analysis. Build them in this order, since each feeds the next.

1. GitHub repo (the analysis itself)
2. LaTeX report (the complete written record)
3. PowerPoint deck (the report distilled)
4. Video (Jake presenting the deck)
5. Web page (summary with links to all of the above)

Structure follows the standards from Jake's earlier presentation research: open with situation, complication, and question; put the headline result in the first three minutes; lead every chapter with its conclusion; close with a recommendation and business value.

---

## 1. LaTeX report

Target 12 to 18 pages plus appendix. Built from Quarto or R Markdown through LaTeX so figures and numbers come from code.

1. **Executive summary** (one page): both answers, the recommendation, the dollar figure, the main limitation
2. **Client and question:** PHX context, why departure-side time loss matters, the two questions
3. **Scope and limitations:** what is measured, what is excluded and why
4. **Data:** five sources, window, coverage, cleaning decisions, validation results
5. **Act 1 findings**
   - Inherited versus PHX-originated delay
   - Gate departure delay by hour, carrier, cause
   - Excess taxi-out
   - Airfield delays and utilization
   - Weather effects on each stage
   - Passenger demand profile
   - Stage ranking in minutes and dollars
6. **Recommendation:** the single best-return fix, mechanism, owner, expected recovery, sensitivity
7. **Act 2 findings**
   - Delay response to load, by stage
   - Scenario results at +5, +10, +15, +20%
   - Which stage degrades first, normal and bad-weather days
   - How soon 15% could arrive, from measured trends
8. **Implications:** what PHX should monitor and when to act
9. **What I would do with better data:** the excluded stages and what data would unlock them
10. **Appendix:** definitions, model output tables, robustness checks, data dictionary, reproduction steps

---

## 2. PowerPoint deck

Target 28 to 34 slides for a 20 to 25 minute video. One idea per slide. Every chart slide has a title that states the finding.

### Opening (slides 1 to 5, about 3 minutes)
1. Title
2. The situation: PHX in numbers
3. The complication and the two questions
4. **Headline results:** both answers on one slide
5. Roadmap, and what this analysis can and cannot see

### Method (slides 6 to 9)
6. Scope: the measured journey from inbound arrival to takeoff
7. Five data sources and what each contributes
8. Tools and pipeline (R, reproducible repo)
9. Key definitions (inherited delay, excess taxi, thresholds)

### Act 1: Where time is lost (slides 10 to 19)
10. Inherited versus PHX-originated delay
11. Gate delay by hour of day
12. Gate delay by cause (Pareto)
13. Excess taxi-out by hour
14. Airfield delays and utilization
15. Weather: extreme heat
16. Weather: storms
17. Passenger demand peaks versus flight peaks
18. **Stage ranking: minutes and dollars per year**
19. **Recommendation: the single best-return fix**

### Act 2: What degrades first (slides 20 to 26)
20. Recap of Act 1 in one slide (allows splitting the video here)
21. How delay responds as hours get busier
22. The growth scenarios
23. Results at +15%, by stage
24. Bad-weather days
25. **Which stage degrades first, and at what growth level**
26. How soon growth could get there

### Close (slides 27 to 32)
27. Business implications for PHX
28. Limitations, stated plainly
29. What better data would unlock
30. What I learned (technical)
31. What I learned (consulting and communication)
32. Links: repo, report, page

---

## 3. Video

**Format:** Jake presenting the deck with voiceover, plus short screen clips of the R code and data where they help.

**Length:** 20 to 25 minutes full version. Split at slide 20 into two uploads if it runs long.

**Also produce:** a 60 to 90 second summary cut (slides 3, 4, 18 or 19, 25) for recruiters and for the top of the web page.

**Chapters (YouTube timestamps):**
- 0:00 The question and the answer
- Scope and data
- How I built it
- Act 1: where time is lost
- The recommendation
- Act 2: 15% growth
- Implications and limitations
- What I learned

**Script notes for Claude Code to draft, Jake to rewrite in his own voice:**
- Open with the business problem and its value before any method.
- State the headline numbers within the first three minutes.
- For each chart: what it shows, what it means, why PHX should care.
- Name tools on screen when first used.
- Say the limitations out loud. It builds credibility.
- "What I learned" covers both the technical side (joining messy public data, tail-number linking, choosing baselines) and the judgment side (cutting stages that could not be measured).

---

## 4. Web page

One page, hosted on the portfolio site.

- Title and one-sentence answer to each question
- Embedded summary video, then the full video
- Three to four key charts with one-line takeaways
- The recommendation with its dollar figure
- Limitations in brief
- Links: GitHub repo, PDF report, slide deck

---

## 5. GitHub repo README (rewrite at the end)

- What the project answers, in two sentences
- Headline findings with one chart
- How to reproduce: prerequisites, script order, expected runtime
- Data sources with links
- Limitations
- Links to report, deck, video
