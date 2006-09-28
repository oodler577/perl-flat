perl -d:DProf pregex-to-pfa.pl "${1}" > test.gdl && ~/distfiles/aiSee/bin/aisee.bin -pngoutput aisee.png test.gdl && qiv aisee.png #&& dprofpp tmon.out
