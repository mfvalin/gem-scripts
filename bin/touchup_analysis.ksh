#!/usr/bin/ksh
#
UPLOAD_dir=${DOMAIN_dir}

arguments=$*
eval `cclargs_lite -D " " $0 \
 -i        "${UPLOAD_dir}/input/ANALYSIS"    ""      "[input analysis file name]" \
 -o        "${UPLOAD_dir}/input/ANALYSIS"    ""      "[directory for output    ]" \
 -zapdate  ""				     ""      "[liste of nomvar for which to zap the date]" \
 -i7i9     "0"				     "1"     "[]" \
 -sd       "0"				     "1"     "[]" \
 -pgsm	   "pgsm"                            ""      "[version of pgsm to use]"   \
++ $arguments`

set -ex

if [ -z "$i" ] ; then
  exit 0
else
  DIR_IN=`dirname $i`
  FILE_IN=`basename $i`
fi

if [ -z "$o" ] ; then
  exit 0
else
  DIR_OU=`dirname $o`
  FILE_OU=`basename $o`
fi

if [ -z "$zapdate" -a $i7i9 -eq 0 -a $sd -eq 0 ] ; then
  exit 0
fi

if [ ! -d $DIR_OU ] ; then
  printf "\n OUTPUT DIRECTORY: $DIR_OU NOT AVAILABLE\n\n"
  exit 1
fi

if [ "$i" == "$o" ] ; then
  ici=`pwd`
  set -ex
  cd $DIR_IN
  mv -f $FILE_IN ${FILE_IN}_orig
  FILE_IN=${FILE_IN}_orig
  set +ex
  cd $ici
fi

FILE_IN=`true_path ${DIR_IN}`/${FILE_IN}
FILE_OUT=`true_path ${DIR_OU}`/${FILE_OU}

cp ${FILE_IN} ${FILE_OUT} ; chmod u+w ${FILE_OUT}

if [ -n "$zapdate" ] ; then
  ladate=-9
  for dat in $(r.fstliste -izfst ${FILE_IN} -nomvar P0 | awk 'BEGIN{FS=":"}{print $25}') ; do
    if [[ ${ladate} -gt 0 && ${ladate} -ne ${dat} ]] ; then
      printf "\n UNABLE to proceed:  MULTIPLE P0 DATES FOUND in ${FILE_IN}\n\n"
      exit 1
    else
      ladate=${dat}
    fi
  done
  if [[ ${ladate} -lt 0 ]] ; then
    printf "\n UNABLE to proceed: P0 NOT AVAILABLE in ${FILE_IN}\n\n"
    exit 1 
  fi
  /bin/rm -f e.dir
  for i in $zapdate ; do
    cat >> e.dir <<EOF
 desire (-1,'$i')
 zap(-1,-1,-1,${ladate})
EOF
  done
echo end >> e.dir
  cat e.dir
  editfst -s ${FILE_IN} -d ${FILE_OUT} -i e.dir
  /bin/rm -f e.dir
fi

if [ $i7i9 -gt 0 ] ; then
  set -A ig $(r.fstliste -izfst ${FILE_IN} -nomvar I9 -col 15,16,17)
  editfst -e -s ${FILE_IN} -d ./i9 <<EOF
 desire(-1,['>>','^^','^>'],-1,-1,${ig[0]},${ig[1]},${ig[2]})
EOF
  ${pgsm} -iment ${FILE_IN} -ozsrt ./i9 <<EOF
 sortie(STD,1000,A)
 heure(all)
 grille(TAPE2,${ig[0]},${ig[1]},${ig[2]})
 SETINTX(LINEAIR)
 champ('TS')
EOF
  editfst -s ./i9 -d ${FILE_OUT} <<EOF
 desire (-1,"TS")
 zap (-1,"I9",-1,-1,1199,6,-1)
EOF
  editfst -s ./i9 -d ${FILE_OUT} <<EOF
 desire (-1,"TS")
 zap (-1,"I7",-1,-1,1199,6,-1)
EOF
  /bin/rm -f ./i9
fi

if [ $sd -gt 0 ] ; then
  dlist=$(r.fstliste -izfst ${FILE_IN} -nomvar SD -col 25)
  for dat in ${dlist} ; do
    if [[ $(r.fstliste -izfst ${FILE_IN} -nomvar SD -datev ${dat} | wc -l) -eq 1 ]] ; then
      editfst -s ${FILE_IN} -d ${FILE_OUT} -i <<EOF
 desire (-1,"SD",-1,${dat})
 zap (-1,-1,-1,-1,1199,-1,-1)
 stdcopi(-1)
 desire (-1,"SD",-1,${dat})
 zap (-1,-1,-1,-1,1198,-1,-1)
 stdcopi(-1)
 desire (-1,"SD",-1,${dat})
 zap (-1,-1,-1,-1,1197,-1,-1)
 stdcopi(-1)
 desire (-1,"SD",-1,${dat})
 zap (-1,-1,-1,-1,1196,-1,-1)
 stdcopi(-1)
 desire (-1,"SD",-1,${dat})
 zap (-1,-1,-1,-1,1195,-1,-1)
 stdcopi(-1)
end
EOF
    fi
  done
fi



