# ocr-script.sh
# 
# Usage:
#  Set this file as the post-processing script in the simple-scan preferences. No extra arguments needed.
#  Any postprocessing script arguments entered in the preferences will be passed along to ocrmypdf, for
#  example, add -l=eng+spa to recognize English and Spanish text.
# 
# Requirements:
# - simple-scan
# - ocrmypdf
# 
# For reference, at the time of writing the arguments from simple-scan are:
# $1    - the mime type, eg application/pdf
# $2    - whether or not to keep a copy of the original file
# $3    - the filename
# $4..N - postprocessing script arguments entered in preferences

# script arguments: -l=eng+deu

filename=$3
keep_original=$2

if [[ "$keep_original" == "true" ]]; then
  ocr_filename="${filename%\.*}.ocr.${filename##*\.}"
  extra_msg_details="Saved as ${ocr_filename##*\/}.\nOriginal saved as ${filename##*\/}."
else
  extra_msg_details="Saved as ${filename##*\/}."
fi
ocrmypdf --deskew --clean --force-ocr "${@:4}" "$filename" "${ocr_filename-$filename}" &> /tmp/ocr.log
if [ $? -ne 0 ]; then
  notify-send -i scanner "OCR Failed" "See /tmp/ocr.log"
  exit 1
fi

notify-send -i scanner "OCR Complete" "$extra_msg_details"
