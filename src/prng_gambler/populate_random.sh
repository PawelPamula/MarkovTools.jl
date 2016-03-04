#!/bin/bash


# make NSEQ random sequences
if [ -z "$NSEQ" ]; then
	NSEQ=4096
fi

# the sequences are BLEN bytes long
if [ -z "$BLEN" ]; then
	BLEN=65536
fi

mkdir -p seq/{N,R}
mkdir -p seq/{N,R}/urand
mkdir -p seq/{N,R}/openssl
mkdir -p seq/{N,R}/rc4
mkdir -p seq/{N,R}/aes128ctr
mkdir -p seq/{N,R}/aes192ctr
mkdir -p seq/{N,R}/aes256ctr
mkdir -p seq/{N,R}/crand
mkdir -p seq/{N,R}/randu

#
# Generate NSEQ random sequences from various sources:
# (the sequences have length of 16kB)
#
# seq/N - the key/seed of each sequence is serial, i.e. 1, 2, 3, ... NSEQ
# seq/R - the key/seed of each sequence is psudorandom 
#
# seq/*/urand/*			: sequence from /dev/urandom
# seq/*/openssl/*		: sequence from openssl rand function
# seq/*/rc4/*			: sequence from RC4 (128 bit key)
# seq/*/aes128ctr/*		: sequence from AES-128-CTR
# seq/*/aes192ctr/*		: sequence from AES-192-CTR
# seq/*/aes256ctr/*		: sequence from AES-256-CTR
# seq/*/crand/*			: sequence of first bytes of C rand() function
# seq/*/randu/*			: sequence of first two bytes of RANDU function
# 

if [ ! -f /c_rand ]; then
	gcc --std=c99 c_rand.c -o c_rand
fi
if [ ! -f /randu ]; then
	gcc --std=c99 randu.c -o randu
fi

function generate # $1: index number $2: file prefix $3: cipher key
{
	i=$1
	FPREFIX=$2
	FKEY=$3
	IHEX="00000000000000000000000000000000" # just for IVs here
	
	KEY32=`echo $FKEY | cut -c1-8`
	DKEY32=`echo $((16#$KEY32))`
	KEY128=`echo $FKEY | cut -c1-32`
	KEY192=`echo $FKEY | cut -c1-48`
	KEY256=$FKEY
	
	BLLEN=$(($BLEN/1024))

	FNAME="$FPREFIX/urand/$i"
	dd if=/dev/urandom of=$FNAME count=$BLLEN bs=1KiB iflag=fullblock status=none &
	P0=$!
	
	FNAME="$FPREFIX/openssl/$i"
	openssl rand -out $FNAME $BLEN &
	P1=$!
	
	FNAME="$FPREFIX/rc4/$i"
	head -c $BLEN /dev/zero | openssl rc4 -out $FNAME -K $KEY128 &
	P2=$!
	
	FNAME="$FPREFIX/aes128ctr/$i"
	head -c $BLEN /dev/zero | openssl enc -aes-128-ctr -out $FNAME -K $KEY128 -iv $IHEX &
	P3=$!
	
	FNAME="$FPREFIX/aes192ctr/$i"
	head -c $BLEN /dev/zero | openssl enc -aes-192-ctr -out $FNAME -K $KEY192 -iv $IHEX &
	P4=$!
	
	FNAME="$FPREFIX/aes256ctr/$i"
	head -c $BLEN /dev/zero | openssl enc -aes-256-ctr -out $FNAME -K $KEY256 -iv $IHEX &
	P5=$!
	
	FNAME="$FPREFIX/crand/$i"
	./c_rand $BLEN $DKEY32 > $FNAME &
	P6=$!
	
	FNAME="$FPREFIX/randu/$i"
	./randu $BLEN $DKEY32 > $FNAME &
	P7=$!
	
	wait $P0
	wait $P1
	wait $P2
	wait $P3
	wait $P4
	wait $P5
	wait $P6
	wait $P7
}

for i in $(seq 1 $NSEQ); do 
	IHEX=`echo "obase=16; $i" | bc`
	generate $i "seq/N" $IHEX
	IHEX=`echo "$i" | sha256sum | cut -c1-64`
	generate $i "seq/R" $IHEX
done
