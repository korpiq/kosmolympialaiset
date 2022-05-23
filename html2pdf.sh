files=$(
    for f in Su*-*.html Se*-*.html
    do
        echo Kosmolympialaistenesittely.html $f
    done
)

wkhtmltopdf --print-media-type $files kosmolympialaistiimit.pdf
