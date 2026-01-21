# #!/bin/bash

mkdir -p $HOME/labs/src/bunniesinc
cd $HOME/labs/src/bunniesinc

git clone git@github.com:alicin/expensepeebs.git
git clone git@github.com:alicin/peach-pocket.git

mkdir -p $HOME/labs/src/bunniesinc/listpop
cd $HOME/labs/src/bunniesinc/listpop
git clone git@github.com:alicin/guest-list.git
git clone git@github.com:alicin/listpop-landing.git

mkdir -p $HOME/labs/src/bunniesinc/projects/agekit.proj
cd $HOME/labs/src/bunniesinc/projects/agekit.proj
git clone git@github.com:alicin/agekit-control.git
git clone git@github.com:alicin/goCamOpenSource.git

