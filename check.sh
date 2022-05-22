for f in *.html
do
    for c in A B C D E F
    do
        COUNT=$(grep -c "$c) " $f)
        [ "$COUNT" = "1" ] || echo "$f has $COUNT of $c"
    done
done
