#!/bin/bash
cd ../../fcheck
STUDENT_DIR=2539/Moklev make
cd ../2539/Moklev
cp ../../fcheck/libhwwrapped.a .
