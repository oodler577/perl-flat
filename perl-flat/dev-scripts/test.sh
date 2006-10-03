perl pregex-to-pfa.pl "${1}"                         
#rm *.gdl *.png
#~/distfiles/aiSee/bin/aisee.bin -pngoutput pfa.png pfa.gdl 
~/distfiles/aiSee/bin/aisee.bin -pngoutput nfa.png nfa.gdl 
#qiv pfa.png&
qiv nfa.png&
