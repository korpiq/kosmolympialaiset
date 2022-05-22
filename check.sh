for f in *.html; do for c in A B C D E F; do grep -q "$c) " $f || echo "$f missing $c"; done; done
