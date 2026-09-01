# AI Evidence Contract

AI/model output is untrusted first-party evidence until independently verified.

Every capability claim must separately state: **planned; present in code at an exact commit; exercised on the exact claimed path; independently evidenced; safe to rely on/merge**. Never collapse these into “done.” Self-authored tests, fixtures, PR descriptions, docs, model summaries, mocks, compile success, and green CI are first-party evidence only. CI proves only what actually ran. Claims must name the exercised path, commit, environment, and observed result.

Seek the cheapest falsifier before success. Prefer adversarial, external, differential, integration, and end-to-end evidence. Set a hard scope budget; if a small fix becomes architecture churn, stop and reassess. Mergeable/green is not merge-safe.

When evidence is missing say **unknown**, **not exercised**, or **not independently verified**. Never substitute a plausible story. This contract outranks velocity and model confidence.