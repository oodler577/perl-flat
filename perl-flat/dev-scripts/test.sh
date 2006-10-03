perl pregex-to-pfa.pl "${1}"                         
#rm *.gdl *.png
~/distfiles/aiSee/bin/aisee.bin -pngoutput pfa.png pfa.gdl 
~/distfiles/aiSee/bin/aisee.bin -pngoutput nfa.png nfa.gdl 
~/distfiles/aiSee/bin/aisee.bin -pngoutput dfa.png dfa.gdl 
~/distfiles/aiSee/bin/aisee.bin -pngoutput mindfa.png mindfa.gdl 
#qiv pfa.png&
#qiv nfa.png&
#qiv dfa.png&
qiv mindfa.png&
