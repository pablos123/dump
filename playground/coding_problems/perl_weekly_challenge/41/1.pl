for(1..50){$v=()=`factor $_`=~/ /g;if($v>=2){$v=()=`factor $v`=~/ /g;if($v==1){print"$_\n"}}}

for(1..50){$v=()=`factor $_`=~/ /g;$v>=2?($v=()=`factor $v`=~/ /g and$v==1)?print"$_\n":0:0}

$v=()=`factor $_`=~/ /g and$v>=2?($v=()=`factor $v`=~/ /g and$v==1)?print"$_\n":0:0for(1..50)

