#!/bin/sh

# color
NONE="\033[0m";
RED="\033[1;31m";
GREEN="\033[1;32m";
YELLOW="\033[1;33m";
BLUE="\033[1;34m";

MAX_RETEST_TIME=2; # if TLE
TMPDIR=".lenon_tmp_dir";

default_student="std";
default_time_limit="1000000000"; # 1s, 1e9ns
default_score_per_problem="100";

# read configure
cfg_problem=`grep "problem" ~/.lenonrc | cut -d '=' -f2`;
cfg_student=`grep "student" ~/.lenonrc | cut -d '=' -f2`;
cfg_time_limit=`grep "time" ~/.lenonrc | cut -d '=' -f2`;
cfg_score_per_problem=`grep "score" ~/.lenonrc | cut -d '=' -f2`;

# ============== problem  =========================
if [ -n "${1}" ]; then
	problem="${1}";
elif [ -n "${cfg_problem}" ]; then
	problem="${cfg_problem}";
else
	echo "Problem name required";
	exit;
fi

# ============ student =========================
if [ -n "${2}" ]; then
	student="${2}";
elif [ -n "${cfg_student}" ]; then
	student="${cfg_student}";
else
	student=${default_student};
fi

# ============ time limit =======================
if [ -n "${3}" ]; then
	time_limit=`echo "${3}"|awk '{printf("%d", $1 * 1000000000)}'`;
elif [ -n "${cfg_time_limit}" ]; then
	time_limit=`echo "${cfg_time_limit}"|awk '{printf("%d", $1 * 1000000000)}'`;
else
	time_limit=${default_time_limit};
fi

# ============ score per problem =======================
if [ -n "${4}" ]; then
	score_per_problem="${4}";
elif [ -n "${cfg_score_per_problem}" ]; then
	score_per_problem="${cfg_score_per_problem}";
else
	score_per_problem=${default_score_per_problem};
fi

# ============ find data =========================
while [ ! -d data ]; do
	cd ../;
	if [ "${PWD}" = '/' ]; then
		echo "No such Problem : ${problem}";
		exit;
	fi
done

# ============ get testcase num  =========================
data_count=0;
while [ -f data/${problem}/${problem}${data_count}.in ];do
	let data_count+=1;
done

if [ ${data_count} -le 0 ]; then
	echo "No test data of ${problem}";
	exit;
fi

score_per_case=`expr "${score_per_problem}" '/' "${data_count}"`;

# ============ clean tmp directory =======================
if [ -d "${TMPDIR}" ]; then
	rm -f "${TMPDIR}/*";
else
	mkdir "${TMPDIR}";
fi

# ============ init special judge =========================
if [ -f "data/${problem}/checker.cpp" ]; then
	SPJ=1;
	g++ "data/${problem}/checker.cpp" -o "${TMPDIR}/checker";
	if [ $? -ne 0 ]; then
		echo "SPJ Checker ERROR! ${problem}";
		exit;
	fi
else
	SPJ=0;
fi

# ============ compile student program =========================
g++ "source/${student}/${problem}.cpp" -o "${TMPDIR}/${problem}" 2>&1;
if [ $? -ne 0 ]; then
	echo -e "${YELLOW}" "CE" "${NONE}";
	exit;
fi

# ============ judge =========================
cd "${TMPDIR}";

totscore=0;

let data_count-=1;
data="-1"; # easy to use `continue`

echo "judge start : ${student} ${problem}";
while [ "${data}" -lt "${data_count}" ]; do
	let data+=1;

	ln -sf "../data/${problem}/${problem}${data}.in" ./${problem}.in;
	chmod a-w ${problem}.in;

	score=0;
	test_times=0;
	time_spend=0;
	is_TLE=1;

	# Run
	while [ ${test_times} -lt ${MAX_RETEST_TIME} ]; do
		start_time=`date +%s%N`;
		end_time=`expr "${start_time}" '+' "${time_limit}"`;
		./${problem} &
		lastpid=${!};

		while [ `date +%s%N` -lt ${end_time} ]; do
			ps -p ${lastpid} 1>/dev/null 2>/dev/null;
			if [ $? -ne 0 ]; then
				break;
			fi
		done

		now_time=`date +%s%N`;
		time_spend=`expr "${now_time}" '-' "${start_time}"`; # ns
		time_spend=`echo "${time_spend}"|awk '{printf("%f", $1 / 1000000000.0)}'`;

		kill -KILL ${lastpid} 1>/dev/null 2>/dev/null;
		if [ $? -eq 0 ]; then
			score=0;
		else
			is_TLE=0;
			score=${score_per_case};
			break;
		fi
		let test_times+=1;
	done

	echo -n "testcase ${data} :"

	# TLE
	if [ ${is_TLE} -eq 1 ]; then
		echo -e "${BLUE}" "TLE\t" "${RED}" "${score}" "${NONE}" " N/A";
		continue;
	fi

	# WA
	if [ ${SPJ} -eq 1 ]; then
		./checker "${problem}.in" "${problem}.out" "${problem}.ans" "${score_per_case}" "score_file" "error_file";
		echo -ne "SPJ\t: "
		score=`cat score_file`;
	else
		ln -sf "../data/${problem}/${problem}${data}.out" ./${problem}.ans;
		diff -Z "${problem}.out" "${problem}.ans" 1>/dev/null 2>/dev/null;
		if [ $? -ne 0 ]; then
			echo -ne "${RED}" "WA\t" "${NONE}";
			score=0;
		else
			echo -ne "${GREEN}" "AC\t" "${NONE}";
			score=${score_per_case};
		fi
	fi

	if [ ${score} -gt 0 ]; then
		echo -ne "${GREEN}";
	else
		echo -ne "${RED}";
	fi
	echo -e "${score}" "${NONE}" " ${time_spend}s";
	let totscore+="${score}";
done

if [ ${totscore} -lt 60 ]; then
	echo -ne "${RED}";
else
	echo -ne "${GREEN}";
fi
echo -e "Tot Score : ${totscore}" "${NONE}";
