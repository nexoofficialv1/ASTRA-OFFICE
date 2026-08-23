# ASTRA OFFICE v0.6.0 Native Office Engine Migration

Office files must not be flattened before the user sees them.

## Phase 1

- DOCX defaults to Original Layout mode.
- Original Layout delegates to an installed Office-compatible Android renderer.
- ASTRA Quick Edit remains separate.
- Quick Edit gets a pinned two-row core formatting toolbar.
- Native ONLYOFFICE Android source is probed in a dedicated CI workflow.

## Final target

- local DOCX/XLSX/PPTX open without layout loss;
- edit in the original formatting context;
- save back to OOXML;
- print/export;
- pinned mobile ribbon;
- no plain-text flattening before rendering.

## Licensing gate

ONLYOFFICE Documents for Android is AGPLv3. Upstream source is not copied into
ASTRA main until the distribution/licensing boundary is resolved.
