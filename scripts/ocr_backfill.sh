#!/usr/bin/env bash
# ocr_backfill.sh
#
# Recursively scan a folder for PDFs and add an OCR text layer to any file
# that doesn't already have one (e.g. documents scanned before the OCR
# post-processing script existed). Files that already contain text are left
# untouched. OCR'd files are rewritten in place.
#
# Detection relies on ocrmypdf's own behaviour: run without --force-ocr or
# --skip-text, it exits with code 6 (already_done_ocr) if the PDF already
# has a text layer.
#
# Usage:
#   ocr_backfill.sh <folder> [extra ocrmypdf args...]
#
# Requirements: ocrmypdf

set -uo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
    echo "Usage: $0 <folder> [extra ocrmypdf args...]"
    exit 1
fi
shift

# --clean is used only to improve OCR accuracy; the visible page is unchanged.
OCR_ARGS=(--deskew --clean -l eng+deu "$@")
LOG=/tmp/ocr_backfill.log
: > "$LOG"

done_count=0
skip_count=0
fail_count=0

while IFS= read -r -d '' pdf; do
    tmp="$(mktemp --suffix=.pdf)"
    out="$(ocrmypdf "${OCR_ARGS[@]}" "$pdf" "$tmp" 2>&1)"
    rc=$?
    echo "$out" >> "$LOG"
    if [[ $rc -eq 0 ]]; then
        mv -f "$tmp" "$pdf"
        echo "OCR'd:   $pdf"
        done_count=$((done_count + 1))
    elif [[ $rc -eq 6 ]] || grep -q "TaggedPDFError" <<<"$out"; then
        # exit 6 = already has a text layer; Tagged PDFs are born-digital
        # (office/online docs) that already contain real text. Both are fine.
        rm -f "$tmp"
        echo "skip:    $pdf (already has text)"
        skip_count=$((skip_count + 1))
    else
        rm -f "$tmp"
        if grep -q "EncryptedPdfError" <<<"$out"; then
            reason="encrypted (remove with: qpdf --decrypt)"
        elif grep -q "DigitalSignatureError" <<<"$out"; then
            reason="digitally signed (OCR would break the signature)"
        elif grep -q "UnsupportedImageFormatError" <<<"$out"; then
            reason="unsupported image format"
        else
            reason="exit $rc"
        fi
        echo "FAILED: $pdf -- $reason"
        echo "FAILED: $pdf -- $reason" >> "$LOG"
        fail_count=$((fail_count + 1))
    fi
done < <(find "$TARGET" -type f -iname '*.pdf' -print0)

echo "----------------------------------------"
echo "OCR'd: $done_count   skipped: $skip_count   failed: $fail_count"
[[ $fail_count -gt 0 ]] && echo "Failures logged in $LOG"
exit 0
